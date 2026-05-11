import NetworkExtension
import WireGuardKit

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { _, message in
            NSLog("WireGuard: \(message)")
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let config = proto.providerConfiguration,
            let wgQuickConfig = config["wgQuickConfig"] as? String
        else {
            completionHandler(WGError.badConfig)
            return
        }

        do {
            let tunnelConfig = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: "wg0")
            adapter.start(tunnelConfiguration: tunnelConfig) { error in
                completionHandler(error)
            }
        } catch {
            completionHandler(WGError.parseError)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { _ in completionHandler() }
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

enum WGError: Error {
    case badConfig
    case parseError
}
