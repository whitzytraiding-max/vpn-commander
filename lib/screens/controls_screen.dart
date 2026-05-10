import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_card.dart';
import '../widgets/steam_button.dart';
import '../widgets/steam_gauge.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({Key? key}) : super(key: key);

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  final List<String> _output = [];
  bool _running = false;
  final ScrollController _scroll = ScrollController();

  void _appendOutput(String text) {
    setState(() {
      _output.addAll(text.split('\n'));
      if (_output.length > 500) _output.removeRange(0, _output.length - 500);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _run(
    BuildContext ctx,
    String label,
    Future<String> Function() action, {
    bool confirm = false,
  }) async {
    if (confirm) {
      final ok = await _confirmDialog(ctx, label);
      if (!ok) return;
    }
    setState(() => _running = true);
    _appendOutput('\n\$ $label');
    try {
      final result = await action();
      _appendOutput(result);
    } catch (e) {
      _appendOutput('ERROR: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  Future<bool> _confirmDialog(BuildContext ctx, String action) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => Dialog(
            backgroundColor: kBgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: kRedDim),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, color: kRedOn, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Confirm: $action?',
                    style: const TextStyle(color: kParchment, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SteamButton(
                        label: 'Cancel',
                        small: true,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      SteamButton(
                        label: 'Confirm',
                        danger: true,
                        small: true,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<VpnProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const SteamLabel('Control Panel'),
              const Spacer(),
              if (_running) const GearSpinner(size: 20),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Control grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ControlTile(
                icon: Icons.restart_alt,
                label: 'Restart\nwg-easy',
                color: kBrass,
                onTap: () => _run(
                  context,
                  'Restart wg-easy',
                  prov.vpn.restartWgEasy,
                ),
              ),
              _ControlTile(
                icon: Icons.refresh,
                label: 'Flush\nWireGuard',
                color: kCopper,
                onTap: () => _run(
                  context,
                  'Flush WireGuard',
                  prov.vpn.flushWireGuard,
                ),
              ),
              _ControlTile(
                icon: Icons.security,
                label: 'Restart\nXray',
                color: kBrassDark,
                onTap: () => _run(
                  context,
                  'Restart Xray',
                  prov.vpn.restartXray,
                ),
              ),
              _ControlTile(
                icon: Icons.shield,
                label: 'iptables\nStatus',
                color: kCopper,
                onTap: () => _run(
                  context,
                  'iptables -L -n -v',
                  prov.vpn.getIptables,
                ),
              ),
              _ControlTile(
                icon: Icons.table_chart,
                label: 'Raw Table\nCheck',
                color: kBrassDark,
                onTap: () => _run(
                  context,
                  'iptables raw table',
                  prov.vpn.getIptablesRaw,
                ),
              ),
              _ControlTile(
                icon: Icons.network_ping,
                label: 'Ping\nTest',
                color: kCopper,
                onTap: () => _run(
                  context,
                  'Ping 8.8.8.8',
                  prov.vpn.pingTest,
                ),
              ),
              _ControlTile(
                icon: Icons.dns,
                label: 'DNS\nTest',
                color: kBrassDark,
                onTap: () => _run(
                  context,
                  'DNS test via 1.1.1.1',
                  prov.vpn.getDnsTest,
                ),
              ),
              _ControlTile(
                icon: Icons.storage,
                label: 'Disk\nUsage',
                color: kCopper,
                onTap: () => _run(
                  context,
                  'df -h /',
                  prov.vpn.getDiskUsage,
                ),
              ),
              _ControlTile(
                icon: Icons.power_settings_new,
                label: 'Reboot\nServer',
                color: kRedDim,
                danger: true,
                onTap: () => _run(
                  context,
                  'Reboot Server',
                  prov.vpn.rebootServer,
                  confirm: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Output terminal
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SteamCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: kBorder)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal, size: 12, color: kBrassLight),
                        const SizedBox(width: 6),
                        const SteamLabel('Output'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _output.clear()),
                          child: const Icon(Icons.clear, size: 14, color: kParchDim),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: kTermBg,
                      padding: const EdgeInsets.all(10),
                      child: ListView.builder(
                        controller: _scroll,
                        itemCount: _output.length,
                        itemBuilder: (_, i) => Text(
                          _output[i],
                          style: TextStyle(
                            color: _output[i].startsWith('\$')
                                ? kBrassLight
                                : _output[i].startsWith('ERROR')
                                    ? kRedOn
                                    : kTermText,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  const _ControlTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SteamCard(
        borderColor: danger ? kRedDim : color.withOpacity(0.5),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: danger ? kRedOn : color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: danger ? kRedOn : kParchment,
                  fontSize: 10,
                  height: 1.4,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
