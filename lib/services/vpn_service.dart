import '../models/peer_info.dart';
import '../models/server_status.dart';
import 'ssh_service.dart';

class VpnService {
  final SshService ssh;

  VpnService(this.ssh);

  Future<String> getUptime() => ssh.run('uptime -p');

  Future<String> getWgStatus() => ssh.run('wg show');

  Future<String> getDiskUsage() => ssh.run('df -h / | tail -1');

  Future<String> getDockerStatus() =>
      ssh.run('docker ps --filter name=wg-easy --format "{{.Status}}"');

  Future<String> restartWgEasy() => ssh.run(
    'cd /root && docker compose -f dc.yml down && docker compose -f dc.yml up -d && echo "wg-easy restarted"',
  );

  Future<String> restartWireGuard() => ssh.run(
    'docker compose -f /root/dc.yml restart wg-easy && echo "WireGuard restarted"',
  );

  Future<String> flushWireGuard() => ssh.run(
    'docker exec wg-easy wg syncconf wg0 <(wg-quick strip wg0) 2>/dev/null || docker compose -f /root/dc.yml restart wg-easy && echo "WireGuard flushed"',
  );

  Future<String> getIptables() => ssh.run('iptables -L -n -v --line-numbers');

  Future<String> getIptablesRaw() => ssh.run('iptables -t raw -L -n -v');

  Future<String> restartXray() =>
      ssh.run('systemctl restart xray && sleep 1 && systemctl status xray --no-pager -l');

  Future<String> getXrayStatus() =>
      ssh.run('systemctl status xray --no-pager -l');

  Future<String> rebootServer() => ssh.run('reboot; echo "Rebooting..."');

  Future<String> pingTest() =>
      ssh.run('ping -c 4 8.8.8.8 | tail -3');

  Future<String> getDnsTest() =>
      ssh.run('dig +short google.com @1.1.1.1 | head -3');

  Stream<String> getLogs({int tail = 100}) =>
      ssh.runStream('docker logs --tail $tail -f wg-easy 2>&1');

  Future<ServerStatus> getStatus() async {
    try {
      final results = await Future.wait([
        getUptime(),
        getDockerStatus(),
        getWgStatus(),
        getPeers(),
      ]);

      final uptime = results[0] as String;
      final dockerStatus = results[1] as String;
      final wgStatus = results[2] as String;
      final peers = results[3] as List<PeerInfo>;

      return ServerStatus(
        isReachable: true,
        dockerRunning: dockerStatus.toLowerCase().contains('up'),
        wireguardUp: wgStatus.contains('interface:'),
        activePeers: peers.where((p) => p.isConnected).length,
        uptime: uptime,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      return ServerStatus.offline();
    }
  }

  Future<List<PeerInfo>> getPeers() async {
    final output = await ssh.run('wg show wg0 dump');
    return _parseWgDump(output);
  }

  List<PeerInfo> _parseWgDump(String dump) {
    final lines = dump.trim().split('\n');
    final peers = <PeerInfo>[];

    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split('\t');
      if (parts.length < 7) continue;

      final pubKey = parts[0];
      final endpoint = parts[2] == '(none)' ? null : parts[2];
      final allowedIps = parts[3];
      final lastHandshakeEpoch = int.tryParse(parts[4]) ?? 0;
      final rxBytes = int.tryParse(parts[5]) ?? 0;
      final txBytes = int.tryParse(parts[6]) ?? 0;

      final allowedIp = allowedIps.split('/').first;

      peers.add(PeerInfo(
        publicKey: pubKey,
        name: kKnownPeers[pubKey],
        endpoint: endpoint,
        allowedIp: allowedIp,
        lastHandshake: lastHandshakeEpoch > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastHandshakeEpoch * 1000)
            : null,
        rxBytes: rxBytes,
        txBytes: txBytes,
      ));
    }

    return peers;
  }
}
