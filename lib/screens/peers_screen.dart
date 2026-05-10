import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_button.dart';
import '../widgets/steam_card.dart';
import '../widgets/steam_gauge.dart';
import '../widgets/peer_tile.dart';

class PeersScreen extends StatelessWidget {
  const PeersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (ctx, prov, _) {
        final peers = prov.peers;
        final connected = peers.where((p) => p.isConnected).length;

        return Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const SteamLabel('Wireguard Peers'),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kBgLight,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      '$connected / ${peers.length} active',
                      style: TextStyle(
                        color: connected > 0 ? kGreenOn : kParchDim,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (prov.loading)
                    const GearSpinner(size: 20)
                  else
                    SteamButton(
                      label: 'Refresh',
                      icon: Icons.refresh,
                      small: true,
                      onPressed: prov.refresh,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Peers list
            Expanded(
              child: peers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GearSpinner(size: 48, color: kBrassDark),
                          const SizedBox(height: 16),
                          Text(
                            prov.loading ? 'LOADING PEERS...' : 'NO PEERS FOUND',
                            style: const TextStyle(
                              color: kParchDim,
                              fontSize: 12,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: peers.length,
                      itemBuilder: (ctx, i) => PeerTile(peer: peers[i], index: i),
                    ),
            ),

            // Footer: wg show raw button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SteamButton(
                label: 'Raw wg show',
                icon: Icons.terminal,
                small: true,
                onPressed: () => _showRawWg(context, prov),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRawWg(BuildContext context, VpnProvider prov) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: kBgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: kBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SteamLabel('wg show output'),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: prov.vpn.getWgStatus(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: GearSpinner());
                  }
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kTermBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        snap.data!,
                        style: const TextStyle(
                          color: kTermText,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SteamButton(
                  label: 'Close',
                  small: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
