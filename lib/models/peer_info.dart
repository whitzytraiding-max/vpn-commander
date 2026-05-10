class PeerInfo {
  final String publicKey;
  final String? name;
  final String? endpoint;
  final String allowedIp;
  final DateTime? lastHandshake;
  final int rxBytes;
  final int txBytes;

  const PeerInfo({
    required this.publicKey,
    this.name,
    this.endpoint,
    required this.allowedIp,
    this.lastHandshake,
    required this.rxBytes,
    required this.txBytes,
  });

  bool get isConnected {
    if (lastHandshake == null) return false;
    return DateTime.now().difference(lastHandshake!).inMinutes < 3;
  }

  String get shortKey {
    if (publicKey.length <= 16) return publicKey;
    return '${publicKey.substring(0, 8)}…${publicKey.substring(publicKey.length - 8)}';
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String get rxFormatted => formatBytes(rxBytes);
  String get txFormatted => formatBytes(txBytes);
}

// Known peer names keyed by public key
const kKnownPeers = <String, String>{
  'qHVWJL5p//9+KJJ78ea9xikIuLHcYZT7NMlwXiOhPW0=': "Michael's iPhone",
  'KLQlEht79vpu5qLm7RR3cc0qtg25Y0W5bG2Vf3uOdmc=': "Michael's PC",
  'KF3Ks/jvmrTihdcz03pCm+CAL2RBE+PH52Opg1tuV3I=': "Morgan's iPhone",
  'qE2o2IB5CwUEkQ1hdAbyzNtTPwR0/jifOatUoGzbKHM=': "Michael's Mac",
  '0Gtmcw2QHEGgCpnQ7EWPdCo7m3eFITB/jNIDWp79GXs=': 'TV Bedroom',
};
