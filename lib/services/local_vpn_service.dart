import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

// Default config is Michael's Mac — edit via Settings on each device
// WebSocket bridge URL — server converts WS frames → UDP to WireGuard.
const _kWsBridgeUrl = 'ws://45.76.177.181:8080';

// AllowedIPs covers 0.0.0.0/0 minus 45.76.177.181/32 so the server itself
// routes through the existing connection (e.g. ExpressVPN) rather than looping
// back through WireGuard. All other traffic goes through the VPN server.
const kDefaultWgConfig = '''[Interface]
PrivateKey = qE2o2IB5CwUEkQ1hdAbyzNtTPwR0/jifOatUoGzbKHM=
Address = 10.8.0.5/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = krNb0RvwqhStEwIZ4DxPRWB8S6hM42L2EP6zHf36nz8=
PresharedKey = TLy+agZsDnbe2yKR3WaNpUQl+WGnODrVw+pYwWktKoU=
Endpoint = 45.76.177.181:443
AllowedIPs = 0.0.0.0/3, 32.0.0.0/5, 40.0.0.0/6, 44.0.0.0/8, 45.0.0.0/10, 45.64.0.0/13, 45.72.0.0/14, 45.76.0.0/17, 45.76.128.0/19, 45.76.160.0/20, 45.76.176.0/24, 45.76.177.0/25, 45.76.177.128/27, 45.76.177.160/28, 45.76.177.176/30, 45.76.177.180/32, 45.76.177.182/31, 45.76.177.184/29, 45.76.177.192/26, 45.76.178.0/23, 45.76.180.0/22, 45.76.184.0/21, 45.76.192.0/18, 45.77.0.0/16, 45.78.0.0/15, 45.80.0.0/12, 45.96.0.0/11, 45.128.0.0/9, 46.0.0.0/7, 48.0.0.0/4, 64.0.0.0/2, 128.0.0.0/1, ::/0
PersistentKeepalive = 25
''';

// iPhone config — paste this in Settings when running on iPhone
const kIPhoneWgConfig = '''[Interface]
PrivateKey = qHVWJL5p//9+KJJ78ea9xikIuLHcYZT7NMlwXiOhPW0=
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = krNb0RvwqhStEwIZ4DxPRWB8S6hM42L2EP6zHf36nz8=
PresharedKey = Ut25N3ZOoJF27PJNLvuYUDbmGt48auyvbl98ogpIqRI=
Endpoint = 45.76.177.181:443
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

const _serverIp = '45.76.177.181';
const _wgExe = r'C:\Program Files\WireGuard\wireguard.exe';
const _providerBundleId = 'com.michaelcarrihill.vpnCommander.WGExtension';

class LocalVpnService {
  String _tunnelName = 'wg0';
  late String _wgConfig = Platform.isIOS ? kIPhoneWgConfig : kDefaultWgConfig;

  String get tunnelName => _tunnelName;
  String get wgConfig => _wgConfig;

  String get _platformDefault => Platform.isIOS ? kIPhoneWgConfig : kDefaultWgConfig;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _tunnelName = prefs.getString('wg_tunnel_name') ?? 'wg0';
    final stored = prefs.getString('wg_config');
    // Migrate: old Mac config had AllowedIPs = 0.0.0.0/0 which conflicts with
    // any upstream VPN (e.g. ExpressVPN) by routing the server IP through itself.
    // Replace with the server-excluded AllowedIPs automatically.
    if (stored != null &&
        !Platform.isIOS &&
        stored.contains('AllowedIPs = 0.0.0.0/0')) {
      _wgConfig = kDefaultWgConfig;
      await prefs.setString('wg_config', _wgConfig);
    } else {
      _wgConfig = stored ?? _platformDefault;
    }
    await _loadTunnelPref();
  }

  Future<void> saveConfig({required String tunnelName, required String config}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wg_tunnel_name', tunnelName);
    await prefs.setString('wg_config', config);
    _tunnelName = tunnelName;
    _wgConfig = config;
  }

  // iOS only — macOS uses osascript, Windows uses wg.exe
  Future<void> initialize() async {
    if (!Platform.isIOS) return;
    await WireGuardFlutter.instance.initialize(interfaceName: _tunnelName);
  }

  // iOS only — macOS and Windows are polled
  Stream<VpnStage> get stageStream => WireGuardFlutter.instance.vpnStageSnapshot;

  Future<int?> pingServer() async {
    if (Platform.isIOS) return null;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        _serverIp, 22,
        timeout: const Duration(seconds: 3),
      );
      final ms = sw.elapsedMilliseconds;
      socket.destroy();
      return ms;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isVpnConnected() async {
    if (Platform.isIOS) {
      final stage = await WireGuardFlutter.instance.stage();
      return stage == VpnStage.connected;
    }
    if (Platform.isMacOS) return _isVpnConnectedMacOS();
    if (Platform.isWindows) {
      try {
        final r = await Process.run('sc', ['query', 'WireGuardTunnel\$$_tunnelName']);
        return r.stdout.toString().contains('RUNNING');
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<String> connect() async {
    if (Platform.isIOS) return _connectIOS();
    if (Platform.isMacOS) return _connectMacOS();
    if (Platform.isWindows) return _connectWindows();
    return 'Platform not supported.';
  }

  Future<String> disconnect() async {
    if (Platform.isIOS) return _disconnectIOS();
    if (Platform.isMacOS) return _disconnectMacOS();
    if (Platform.isWindows) return _disconnectWindows();
    return 'Platform not supported.';
  }

  // Whether to route WireGuard traffic over the WebSocket TCP bridge.
  // Defaults ON for iOS because Myanmar ISP DPI blocks WireGuard UDP.
  bool _wsTunnelEnabled = Platform.isIOS;
  bool get wsTunnelEnabled => _wsTunnelEnabled;

  Future<void> setWsTunnel(bool enabled) async {
    _wsTunnelEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ws_tunnel_enabled', enabled);
  }

  Future<void> _loadTunnelPref() async {
    final prefs = await SharedPreferences.getInstance();
    _wsTunnelEnabled = prefs.getBool('ws_tunnel_enabled') ?? Platform.isIOS;
  }

  // ── iOS: WireGuard via Network Extension (wireguard_flutter) ──────────────

  Future<String> _connectIOS() async {
    try {
      final endpoint = _extractEndpoint();
      final config = _wsTunnelEnabled ? _injectWsTunnel(_wgConfig) : _wgConfig;
      await WireGuardFlutter.instance.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: _providerBundleId,
      );
      return _wsTunnelEnabled ? 'Connecting via WebSocket tunnel...' : 'Connecting...';
    } catch (e) {
      return 'Error: $e';
    }
  }

  String _injectWsTunnel(String config) =>
      '#WS_TUNNEL = $_kWsBridgeUrl\n$config';

  Future<String> _disconnectIOS() async {
    try {
      await WireGuardFlutter.instance.stopVpn();
      return 'Disconnected';
    } catch (e) {
      return 'Error: $e';
    }
  }

  String _extractEndpoint() {
    final m = RegExp(r'Endpoint\s*=\s*([^\n]+)').firstMatch(_wgConfig);
    return m?.group(1)?.trim() ?? '45.76.177.181:51820';
  }

  // ── macOS: scutil --nc controls the WireGuard App tunnel ─────────────────

  // Discovers the first WireGuard tunnel name registered in system VPN prefs.
  Future<String?> _macOsWgTunnelName() async {
    try {
      final r = await Process.run('scutil', ['--nc', 'list']);
      final out = r.stdout.toString();
      final match = RegExp(r'"([^"]+)"\s*\[VPN:com\.wireguard').firstMatch(out);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  // Checks if the stored tunnel config is outdated.
  // scutil --nc show exposes RemoteAddress but not the full wgQuickConfig, so
  // we use the port as a proxy: old configs point to 51820, new ones use 443.
  Future<bool> _macOsTunnelHasOldConfig(String name) async {
    try {
      final r = await Process.run('scutil', ['--nc', 'show', name]);
      return r.stdout.toString().contains(':51820');
    } catch (_) {
      return false;
    }
  }

  // Writes the current WG config to /tmp/<name>.conf and reveals it in Finder
  // alongside WireGuard, ready for File → Import tunnel(s) from file.
  Future<void> _exportConfigToWireGuardApp(String name) async {
    final path = '/tmp/$name.conf';
    await File(path).writeAsString(_wgConfig);
    await Process.run('open', ['-R', path]); // reveal in Finder
    await Process.run('open', ['-a', 'WireGuard']); // bring WireGuard to front
  }

  // Public: called from Settings "Repair Tunnel" button.
  Future<String> repairMacTunnel() async {
    try {
      final name = await _macOsWgTunnelName() ?? _tunnelName;
      await _exportConfigToWireGuardApp(name);
      return 'Config saved to /tmp/$name.conf\n'
          'In WireGuard: File → Import tunnel(s) from file → select that file.\n'
          'Then tap Connect.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> _isVpnConnectedMacOS() async {
    try {
      final name = await _macOsWgTunnelName();
      if (name == null) return false;
      final r = await Process.run('scutil', ['--nc', 'status', name]);
      return r.stdout.toString().trim().startsWith('Connected');
    } catch (_) {
      return false;
    }
  }

  Future<String> _connectMacOS() async {
    try {
      final name = await _macOsWgTunnelName();
      if (name == null) {
        // No WireGuard App tunnel found — export config for first-time import.
        await _exportConfigToWireGuardApp(_tunnelName);
        return 'No WireGuard tunnel found — config saved to /tmp/$_tunnelName.conf\n'
            'WireGuard: File → Import tunnel(s) from file → select that file.\n'
            'Then tap Connect.';
      }
      if (await _macOsTunnelHasOldConfig(name)) {
        // Old config (port 51820, AllowedIPs = 0.0.0.0/0) breaks ExpressVPN routing.
        // Export updated config and guide user through WireGuard App import.
        await _exportConfigToWireGuardApp(name);
        return 'Tunnel needs updating — config saved to /tmp/$name.conf\n'
            'WireGuard: File → Import tunnel(s) from file → select that file.\n'
            'Then tap Connect again.';
      }
      final r = await Process.run('scutil', ['--nc', 'start', name]);
      if (r.exitCode == 0) return 'Connecting "$name"...';
      final err = (r.stderr.toString() + r.stdout.toString()).trim();
      return 'Connect failed:\n${err.isNotEmpty ? err : "exit ${r.exitCode}"}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _disconnectMacOS() async {
    try {
      final name = await _macOsWgTunnelName();
      if (name == null) return 'No WireGuard tunnel found.';
      final r = await Process.run('scutil', ['--nc', 'stop', name]);
      if (r.exitCode == 0) return 'Disconnected "$name"';
      final err = (r.stderr.toString() + r.stdout.toString()).trim();
      return 'Disconnect failed:\n${err.isNotEmpty ? err : "exit ${r.exitCode}"}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ── Windows: WireGuard service via wireguard.exe ───────────────────────────

  Future<String> _connectWindows() async {
    if (!File(_wgExe).existsSync()) {
      return 'WireGuard not found at $_wgExe\nInstall WireGuard from wireguard.com first.';
    }
    if (await isVpnConnected()) {
      await Process.run('sc', ['stop', 'WireGuardTunnel\$$_tunnelName']);
      await Future.delayed(const Duration(milliseconds: 800));
      await Process.run('sc', ['delete', 'WireGuardTunnel\$$_tunnelName']);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final confPath = '${Directory.systemTemp.path}\\$_tunnelName.conf';
    await File(confPath).writeAsString(_wgConfig);
    final result = await Process.run(_wgExe, ['/installtunnelservice', confPath]);
    if (result.exitCode == 0) {
      for (var i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isVpnConnected()) return 'Connected';
      }
      return 'Tunnel installed — waiting for connection...';
    }
    final err = result.stderr.toString().trim();
    return 'Connect failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
  }

  Future<String> _disconnectWindows() async {
    if (!File(_wgExe).existsSync()) return 'WireGuard not found at $_wgExe';
    final result = await Process.run(_wgExe, ['/uninstalltunnelservice', _tunnelName]);
    if (result.exitCode == 0) return 'Disconnected';
    final err = result.stderr.toString().trim();
    return 'Disconnect failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
  }
}
