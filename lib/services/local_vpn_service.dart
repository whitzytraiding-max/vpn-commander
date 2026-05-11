import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

const kDefaultWgConfig = '''[Interface]
PrivateKey = KLQlEht79vpu5qLm7RR3cc0qtg25Y0W5bG2Vf3uOdmc=
Address = 10.8.0.3/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = krNb0RvwqhStEwIZ4DxPRWB8S6hM42L2EP6zHf36nz8=
PresharedKey = 4HNsipl5BID6LluIKkjEIqtZrn0y4PBSkI0WlnplpPY=
Endpoint = 45.76.177.181:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

String get kDefaultTunnelName => Platform.isWindows ? 'Michaels-PC' : 'wg0';

const _serverIp = '45.76.177.181';
const _wgExe = r'C:\Program Files\WireGuard\wireguard.exe';

class LocalVpnService {
  String _tunnelName = Platform.isWindows ? 'Michaels-PC' : 'wg0';
  String _wgConfig = kDefaultWgConfig;

  String get tunnelName => _tunnelName;
  String get wgConfig => _wgConfig;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _tunnelName = prefs.getString('wg_tunnel_name') ?? kDefaultTunnelName;
    _wgConfig = prefs.getString('wg_config') ?? kDefaultWgConfig;
  }

  Future<void> saveConfig({required String tunnelName, required String config}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wg_tunnel_name', tunnelName);
    await prefs.setString('wg_config', config);
    _tunnelName = tunnelName;
    _wgConfig = config;
  }

  Future<int?> pingServer() async {
    if (Platform.isIOS || Platform.isAndroid) return null;
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
    if (Platform.isIOS || Platform.isAndroid) return false;
    try {
      if (Platform.isWindows) {
        final r = await Process.run('sc', ['query', 'WireGuardTunnel\$$_tunnelName']);
        return r.stdout.toString().contains('RUNNING');
      }
      // macOS: wg show exits 0 and prints interface info when up
      final r = await Process.run('wg', ['show', _tunnelName]);
      return r.exitCode == 0 && r.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> connect() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return 'Local VPN control not supported on mobile.\nUse the WireGuard app to connect.';
    }
    if (Platform.isWindows) return _connectWindows();
    return _connectMacOS();
  }

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

  Future<String> _connectMacOS() async {
    final which = await Process.run('which', ['wg-quick']);
    if (which.exitCode != 0) {
      return 'wg-quick not found.\n'
          'Install WireGuard tools:\n  brew install wireguard-tools\n\n'
          'Or use the WireGuard app from the Mac App Store.';
    }
    final confPath = '/tmp/$_tunnelName.conf';
    await File(confPath).writeAsString(_wgConfig);
    // osascript elevates to admin — prompts user for password
    final script = 'do shell script "wg-quick up $confPath" with administrator privileges';
    final result = await Process.run('osascript', ['-e', script]);
    if (result.exitCode == 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isVpnConnected()) return 'Connected';
      return 'Tunnel starting...';
    }
    final err = result.stderr.toString().trim();
    if (err.contains('User canceled')) return 'Cancelled by user.';
    return 'Connect failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
  }

  Future<String> disconnect() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return 'Use the WireGuard app to disconnect.';
    }
    if (Platform.isWindows) {
      if (!File(_wgExe).existsSync()) return 'WireGuard not found at $_wgExe';
      final result = await Process.run(_wgExe, ['/uninstalltunnelservice', _tunnelName]);
      if (result.exitCode == 0) return 'Disconnected';
      final err = result.stderr.toString().trim();
      return 'Disconnect failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
    }
    // macOS
    final which = await Process.run('which', ['wg-quick']);
    if (which.exitCode != 0) return 'wg-quick not found.';
    final script = 'do shell script "wg-quick down $_tunnelName" with administrator privileges';
    final result = await Process.run('osascript', ['-e', script]);
    if (result.exitCode == 0) return 'Disconnected';
    final err = result.stderr.toString().trim();
    if (err.contains('User canceled')) return 'Cancelled by user.';
    return 'Disconnect failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
  }
}
