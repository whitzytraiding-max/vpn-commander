// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: String, Error {
    case invalidProtocolConfiguration
    case cantParseWgQuickConfig
}

// Reads #WS_TUNNEL = ws://host:port from a wg-quick config comment.
private func extractWsUrl(_ config: String) -> URL? {
    for line in config.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#WS_TUNNEL"), let eq = t.firstIndex(of: "=") {
            let raw = t[t.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            return URL(string: raw)
        }
    }
    return nil
}

// Strip #WS_TUNNEL comment and rewrite Endpoint to 127.0.0.1:localPort.
private func patchConfig(_ config: String, localPort: UInt16) -> String {
    config.components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#WS_TUNNEL") }
        .map { line -> String in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix("endpoint") {
                return "Endpoint = 127.0.0.1:\(localPort)"
            }
            return line
        }
        .joined(separator: "\n")
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { [weak self] _, message in
            self?.log(message)
        }
    }()

    // Holds the WebSocket bridge task so it stays alive.
    private var wsBridgeTask: Task<Void, Never>?
    private var localUdpPort: UInt16 = 0

    func log(_ message: String) {
        NSLog("WireGuardTunnel: %@\n", message)
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log("Starting tunnel")
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration["wgQuickConfig"] as? String else {
            log("Invalid provider configuration")
            completionHandler(PacketTunnelProviderError.invalidProtocolConfiguration)
            return
        }

        if let wsUrl = extractWsUrl(wgQuickConfig) {
            log("WebSocket tunnel mode: \(wsUrl)")
            startWithWsTunnel(originalConfig: wgQuickConfig, wsUrl: wsUrl, completionHandler: completionHandler)
        } else {
            log("Direct mode")
            startDirect(config: wgQuickConfig, completionHandler: completionHandler)
        }
    }

    private func startDirect(config: String, completionHandler: @escaping (Error?) -> Void) {
        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: config) else {
            log("Failed to parse wg-quick config")
            completionHandler(PacketTunnelProviderError.cantParseWgQuickConfig)
            return
        }
        adapter.start(tunnelConfiguration: tunnelConfiguration) { [weak self] adapterError in
            guard let self = self else { return }
            if let adapterError = adapterError {
                self.log("Adapter error: \(adapterError.localizedDescription)")
            } else {
                self.log("Tunnel interface: \(self.adapter.interfaceName ?? "unknown")")
            }
            completionHandler(adapterError)
        }
    }

    private func startWithWsTunnel(originalConfig: String, wsUrl: URL,
                                   completionHandler: @escaping (Error?) -> Void) {
        // Bind a random local UDP port that WireGuard will talk to.
        guard let port = bindFreeUdpPort() else {
            log("Failed to bind local UDP port for WS bridge")
            completionHandler(PacketTunnelProviderError.invalidProtocolConfiguration)
            return
        }
        localUdpPort = port
        log("WS bridge: local UDP port \(port)")

        let patchedConfig = patchConfig(originalConfig, localPort: port)
        log("Patched config endpoint → 127.0.0.1:\(port)")

        // Start the WebSocket ↔ UDP bridge as a background task.
        wsBridgeTask = Task {
            await runWsBridge(wsUrl: wsUrl, localPort: port)
        }

        // Give the bridge a moment to connect before WireGuard tries to handshake.
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            self.startDirect(config: patchedConfig, completionHandler: completionHandler)
        }
    }

    // Returns a free UDP port by binding and immediately releasing.
    private func bindFreeUdpPort() -> UInt16? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }
        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(sock, $0, &len)
            }
        }
        return UInt16(bigEndian: boundAddr.sin_port)
    }

    // Bidirectional WebSocket ↔ local UDP bridge.
    private func runWsBridge(wsUrl: URL, localPort: UInt16) async {
        log("WS bridge starting → \(wsUrl)")

        // Local UDP socket that WireGuard sends packets to.
        let udpSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard udpSock >= 0 else { log("WS bridge: failed to create UDP socket"); return }
        defer { close(udpSock) }

        var bindAddr = sockaddr_in()
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = localPort.bigEndian
        bindAddr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        let bound = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(udpSock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { log("WS bridge: bind failed"); return }

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: wsUrl)
        ws.resume()

        // Track the WireGuard sender address so we can reply correctly.
        var wgSenderAddr: sockaddr_in? = nil

        // UDP → WebSocket
        let udpToWs = Task {
            var buf = [UInt8](repeating: 0, count: 65536)
            while !Task.isCancelled {
                var senderAddr = sockaddr_in()
                var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let n = withUnsafeMutablePointer(to: &senderAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(udpSock, &buf, buf.count, 0, $0, &senderLen)
                    }
                }
                guard n > 0 else { break }
                wgSenderAddr = senderAddr
                let data = Data(buf[..<n])
                do {
                    try await ws.send(.data(data))
                } catch {
                    self.log("WS bridge: WS send error: \(error)")
                    break
                }
            }
        }

        // WebSocket → UDP
        func receiveLoop() {
            ws.receive { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    var data: Data
                    switch msg {
                    case .data(let d): data = d
                    case .string(let s): data = Data(s.utf8)
                    @unknown default: return
                    }
                    if var sender = wgSenderAddr {
                        data.withUnsafeBytes { ptr in
                            withUnsafePointer(to: &sender) {
                                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                    sendto(udpSock, ptr.baseAddress!, data.count, 0,
                                           $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                                }
                            }
                        }
                    }
                    receiveLoop()
                case .failure(let err):
                    self.log("WS bridge: WS recv error: \(err)")
                }
            }
        }
        receiveLoop()

        await udpToWs.value
        ws.cancel()
        log("WS bridge stopped")
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("Stopping tunnel (reason: \(reason.rawValue))")
        wsBridgeTask?.cancel()
        wsBridgeTask = nil
        adapter.stop { [weak self] error in
            if let error = error {
                self?.log("Stop error: \(error.localizedDescription)")
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let handler = completionHandler else { return }
        if messageData.count == 1 && messageData[0] == 0 {
            adapter.getRuntimeConfiguration { settings in
                handler(settings?.data(using: .utf8))
            }
        } else {
            handler(nil)
        }
    }
}
