import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

// Default config is Michael's Mac — edit via Settings on each device
const kDefaultWgConfig = '''[Interface]
PrivateKey = qE2o2IB5CwUEkQ1hdAbyzNtTPwR0/jifOatUoGzbKHM=
Address = 10.8.0.5/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = krNb0RvwqhStEwIZ4DxPRWB8S6hM42L2EP6zHf36nz8=
PresharedKey = TLy+agZsDnbe2yKR3WaNpUQl+WGnODrVw+pYwWktKoU=
Endpoint = 45.76.177.181:51820
AllowedIPs = 0.0.0.0/0, ::/0
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
Endpoint = 45.76.177.181:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

const _serverIp = '45.76.177.181';
const _wgExe = r'C:\Program Files\WireGuard\wireguard.exe';
const _providerBundleId = 'com.michaelcarrihill.vpnCommander.WGExtension';

class LocalVpnService {
  String _tunnelName = 'wg0';
  String _wgConfig = kDefaultWgConfig;

  String get tunnelName => _tunnelName;
  String get wgConfig => _wgConfig;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _tunnelName = prefs.getString('wg_tunnel_name') ?? 'wg0';
    _wgConfig = prefs.getString('wg_config') ?? kDefaultWgConfig;
  }

  Future<void> saveConfig({required String tunnelName, required String config}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wg_tunnel_name', tunnelName);
    await prefs.setString('wg_config', config);
    _tunnelName = tunnelName;
    _wgConfig = config;
  }

  // Called once at startup on iOS/macOS
  Future<void> initialize() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    await WireGuardFlutter.instance.initialize(interfaceName: _tunnelName);
  }

  // Live stage stream for iOS/macOS
  Stream<VpnStage> get stageStream => WireGuardFlutter.instance.vpnStageSnapshot;

  Future<int?> pingServer() async {
    if (Platform.isIOS) return null;
    try {
      final args = Platform.isWindows
          ? ['-n', '1', '-w', '2000', _serverIp]
          : ['-c', '1', '-t', '3', _serverIp];
      final result = await Process.run('ping', args, runInShell: Platform.isWindows);
      final output = result.stdout.toString();
      final match = Platform.isWindows
          ? RegExp(r'Average\s*=\s*(\d+)ms', caseSensitive: false).firstMatch(output)
          : RegExp(r'round-trip[^=]+=\s*[\d.]+/([\d.]+)', caseSensitive: false).firstMatch(output);
      if (match != null) return double.tryParse(match.group(1) ?? '')?.round();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isVpnConnected() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final stage = await WireGuardFlutter.instance.stage();
      return stage == VpnStage.connected;
    }
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
    if (Platform.isIOS || Platform.isMacOS) return _connectNative();
    if (Platform.isWindows) return _connectWindows();
    return 'Platform not supported.';
  }

  Future<String> disconnect() async {
    if (Platform.isIOS || Platform.isMacOS) return _disconnectNative();
    if (Platform.isWindows) return _disconnectWindows();
    return 'Platform not supported.';
  }

  // ── iOS / macOS: WireGuard via Network Extension ──────────────────────────

  Future<String> _connectNative() async {
    try {
      final endpoint = _extractEndpoint();
      await WireGuardFlutter.instance.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: _wgConfig,
        providerBundleIdentifier: _providerBundleId,
      );
      return 'Connecting...';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _disconnectNative() async {
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
