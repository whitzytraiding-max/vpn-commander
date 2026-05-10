class ServerStatus {
  final bool isReachable;
  final int? pingMs;
  final bool dockerRunning;
  final bool wireguardUp;
  final int activePeers;
  final String uptime;
  final DateTime checkedAt;

  const ServerStatus({
    required this.isReachable,
    this.pingMs,
    required this.dockerRunning,
    required this.wireguardUp,
    required this.activePeers,
    this.uptime = '',
    required this.checkedAt,
  });

  factory ServerStatus.offline() => ServerStatus(
        isReachable: false,
        dockerRunning: false,
        wireguardUp: false,
        activePeers: 0,
        checkedAt: DateTime.now(),
      );
}
