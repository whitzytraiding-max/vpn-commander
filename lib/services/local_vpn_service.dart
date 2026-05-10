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

const kDefaultTunnelName = 'Michaels-PC';
const _serverIp = '45.76.177.181';

// WireGuard Windows app CLI path
const _wgExe = r'C:\Program Files\WireGuard\wireguard.exe';

class LocalVpnService {
  String _tunnelName = kDefaultTunnelName;
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
    try {
      final result = await Process.run(
        'ping', ['-n', '1', '-w', '2000', _serverIp],
        runInShell: true,
      );
      final output = result.stdout.toString();
      final match = RegExp(r'Average\s*=\s*(\d+)ms|time[<=](\d+)ms', caseSensitive: false)
          .firstMatch(output);
      if (match != null) {
        return int.tryParse(match.group(1) ?? match.group(2) ?? '');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isVpnConnected() async {
    // Check the tunnel service status via sc.exe — works without admin, no $ issues
    final result = await Process.run(
      'sc', ['query', 'WireGuardTunnel\$$_tunnelName'],
      runInShell: false,
    );
    return result.stdout.toString().contains('RUNNING');
  }

  Future<String> connect() async {
    if (!File(_wgExe).existsSync()) {
      return 'WireGuard not found at $_wgExe\nInstall WireGuard for Windows from wireguard.com';
    }

    // Write config to a known temp path (name = tunnel name, required by wireguard.exe)
    final confPath = '${Directory.systemTemp.path}\\$_tunnelName.conf';
    await File(confPath).writeAsString(_wgConfig);

    // wireguard.exe /installtunnel requires admin — elevate via UAC
    return _runElevated('"$_wgExe" /installtunnelservice "$confPath"', 'Connect');
  }

  Future<String> disconnect() async {
    if (!File(_wgExe).existsSync()) {
      return 'WireGuard not found at $_wgExe';
    }
    return _runElevated('"$_wgExe" /uninstalltunnelservice "$_tunnelName"', 'Disconnect');
  }

  Future<String> _runElevated(String command, String label) async {
    try {
      // Write to a .bat to avoid quoting nightmares
      final batPath = '${Directory.systemTemp.path}\\wg_cmd.bat';
      await File(batPath).writeAsString('@echo off\n$command\n');

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command',
         'Start-Process cmd -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList \'/c,"$batPath"\''],
        runInShell: false,
      );

      if (result.exitCode == 0) {
        return '$label command sent (UAC prompt shown).';
      }
      final err = result.stderr.toString().trim();
      return '$label failed: ${err.isNotEmpty ? err : "exit ${result.exitCode}"}';
    } catch (e) {
      return '$label error: $e';
    }
  }
}
