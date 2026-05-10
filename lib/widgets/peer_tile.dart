import 'package:flutter/material.dart';
import '../models/peer_info.dart';
import '../theme/colors.dart';
import 'steam_card.dart';

class PeerTile extends StatelessWidget {
  final PeerInfo peer;
  final int index;

  const PeerTile({Key? key, required this.peer, required this.index}) : super(key: key);

  String _handshakeAgo() {
    if (peer.lastHandshake == null) return 'Never';
    final diff = DateTime.now().difference(peer.lastHandshake!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final connected = peer.isConnected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SteamCard(
        borderColor: connected ? kGreenDim : kBorder,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? kGreenOn : kParchDim,
                boxShadow: connected
                    ? [BoxShadow(color: kGreenOn.withOpacity(0.5), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            // Peer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        peer.name ?? 'Peer ${index + 1}',
                        style: const TextStyle(
                          color: kParchment,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kBgLight,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: kBorder),
                        ),
                        child: Text(
                          peer.allowedIp,
                          style: const TextStyle(color: kBrassLight, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peer.shortKey,
                    style: const TextStyle(color: kParchDim, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _statChip(Icons.arrow_downward, peer.rxFormatted, kGreenDim),
                      const SizedBox(width: 8),
                      _statChip(Icons.arrow_upward, peer.txFormatted, kRedDim),
                      const Spacer(),
                      Text(
                        'Handshake: ${_handshakeAgo()}',
                        style: TextStyle(
                          color: connected ? kGreenOn : kParchDim,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (peer.endpoint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      peer.endpoint!,
                      style: const TextStyle(color: kParchDim, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(val, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}
