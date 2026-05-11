import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_card.dart';
import '../widgets/steam_button.dart';
import '../widgets/steam_gauge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (ctx, prov, _) {
        final status = prov.status;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const SteamLabel('System Status'),
                  const Spacer(),
                  if (prov.loading)
                    const GearSpinner(size: 24)
                  else
                    SteamButton(
                      label: 'Refresh',
                      icon: Icons.refresh,
                      small: true,
                      onPressed: prov.refresh,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // VPN TOGGLE — big prominent button
              _VpnToggleCard(prov: prov),
              const SizedBox(height: 16),

              // Main status row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status gauge
                  SteamCard(
                    padding: const EdgeInsets.all(24),
                    child: StatusGauge(
                      online: status?.isReachable ?? false,
                      pingMs: prov.pingMs,
                      label: 'VPN SERVER',
                      size: 130,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stats column
                  Expanded(
                    child: Column(
                      children: [
                        _StatCard(
                          icon: Icons.dns,
                          label: 'Server',
                          value: '45.76.177.181',
                          sub: 'Singapore · Vultr',
                        ),
                        const SizedBox(height: 10),
                        _StatCard(
                          icon: Icons.people,
                          label: 'Active Peers',
                          value: '${status?.activePeers ?? 0} / ${prov.peers.length}',
                          sub: 'WireGuard clients',
                          highlight: (status?.activePeers ?? 0) > 0,
                        ),
                        const SizedBox(height: 10),
                        _PingCard(prov: prov),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Uptime
              if (status != null && status.uptime.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SteamCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: kBrass, size: 16),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Uptime', style: TextStyle(color: kParchDim, fontSize: 10)),
                            Text(status.uptime,
                                style: const TextStyle(color: kParchment, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Service status row
              Row(children: [
                Expanded(
                  child: _ServiceBadge(
                    label: 'WireGuard',
                    active: status?.wireguardUp ?? false,
                    icon: Icons.vpn_lock,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServiceBadge(
                    label: 'wg-easy',
                    active: status?.dockerRunning ?? false,
                    icon: Icons.widgets,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServiceBadge(
                    label: 'SSH',
                    active: prov.isConnected,
                    icon: Icons.terminal,
                  ),
                ),
              ]),

              // Error display
              if (prov.error != null) ...[
                const SizedBox(height: 16),
                SteamCard(
                  borderColor: kRedDim,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: kRedOn, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(prov.error!,
                            style: const TextStyle(color: kRedOn, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              if (status != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Last updated: ${_formatTime(status.checkedAt)}',
                  style: const TextStyle(color: kParchDim, fontSize: 10),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _VpnToggleCard extends StatefulWidget {
  final VpnProvider prov;
  const _VpnToggleCard({required this.prov});

  @override
  State<_VpnToggleCard> createState() => _VpnToggleCardState();
}

class _VpnToggleCardState extends State<_VpnToggleCard> {
  bool _toggling = false;
  String? _message;

  Future<void> _toggle() async {
    setState(() { _toggling = true; _message = null; });
    final result = await widget.prov.toggleVpn();
    if (mounted) setState(() { _toggling = false; _message = result; });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });
  }

  String _stageLabel(VpnStage stage) {
    switch (stage) {
      case VpnStage.connected:       return 'CONNECTED';
      case VpnStage.connecting:      return 'CONNECTING...';
      case VpnStage.disconnecting:   return 'DISCONNECTING...';
      case VpnStage.authenticating:  return 'AUTHENTICATING...';
      case VpnStage.reconnect:       return 'RECONNECTING...';
      case VpnStage.waitingConnection: return 'WAITING...';
      case VpnStage.preparing:       return 'PREPARING...';
      case VpnStage.denied:          return 'PERMISSION DENIED';
      case VpnStage.noConnection:    return 'NO CONNECTION';
      default:                       return 'DISCONNECTED';
    }
  }

  Color _stageColor(VpnStage stage) {
    switch (stage) {
      case VpnStage.connected:  return kGreenOn;
      case VpnStage.denied:
      case VpnStage.noConnection: return kRedOn;
      case VpnStage.connecting:
      case VpnStage.authenticating:
      case VpnStage.preparing:
      case VpnStage.reconnect:
      case VpnStage.waitingConnection: return kBrassLight;
      default: return kParchDim;
    }
  }

  bool _isBusy(VpnStage stage) {
    return stage == VpnStage.connecting ||
        stage == VpnStage.disconnecting ||
        stage == VpnStage.authenticating ||
        stage == VpnStage.preparing ||
        stage == VpnStage.waitingConnection ||
        stage == VpnStage.reconnect;
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.prov.vpnStage;
    final connected = widget.prov.vpnConnected;
    final busy = _toggling || _isBusy(stage);
    final color = _stageColor(stage);

    return SteamCard(
      borderColor: connected ? kGreenDim : kBorder,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: connected
                      ? [BoxShadow(color: kGreenOn.withOpacity(0.6), blurRadius: 10)]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SteamLabel('Local VPN'),
                  Text(
                    _stageLabel(stage),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (busy)
                const GearSpinner(size: 28)
              else
                SteamButton(
                  label: connected ? 'Disconnect' : 'Connect',
                  icon: connected ? Icons.power_off : Icons.power,
                  danger: connected,
                  onPressed: _toggle,
                ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kTermBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _message!,
                style: const TextStyle(color: kTermText, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PingCard extends StatefulWidget {
  final VpnProvider prov;
  const _PingCard({required this.prov});

  @override
  State<_PingCard> createState() => _PingCardState();
}

class _PingCardState extends State<_PingCard> {
  bool _pinging = false;

  Future<void> _ping() async {
    setState(() => _pinging = true);
    await widget.prov.doPingNow();
    if (mounted) setState(() => _pinging = false);
  }

  Color _pingColor(int? ms) {
    if (ms == null) return kParchDim;
    if (ms < 50) return kGreenOn;
    if (ms < 150) return kBrassLight;
    return kRedOn;
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.prov.pingMs;
    return SteamCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: ms != null && ms < 150 ? kGreenDim : kBorder,
      child: Row(
        children: [
          Icon(Icons.network_ping, color: kBrass, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Server Ping', style: TextStyle(color: kParchDim, fontSize: 10)),
                Text(
                  ms != null ? '${ms}ms' : '--',
                  style: TextStyle(
                    color: _pingColor(ms),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ms == null ? 'unreachable' : ms < 50 ? 'excellent' : ms < 150 ? 'good' : 'slow',
                  style: TextStyle(color: _pingColor(ms), fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _pinging ? null : _ping,
            child: _pinging
                ? const GearSpinner(size: 18)
                : const Icon(Icons.refresh, color: kParchDim, size: 16),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool highlight;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: highlight ? kGreenDim : kBorder,
      child: Row(
        children: [
          Icon(icon, color: kBrass, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kParchDim, fontSize: 10, letterSpacing: 1)),
              Text(
                value,
                style: TextStyle(
                  color: highlight ? kGreenOn : kParchment,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(sub, style: const TextStyle(color: kParchDim, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;

  const _ServiceBadge({required this.label, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      borderColor: active ? kGreenDim : kRedDim,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: active ? kGreenOn : kRedOn),
          const SizedBox(width: 6),
          Column(
            children: [
              Text(label, style: const TextStyle(color: kParchment, fontSize: 11)),
              Text(
                active ? 'RUNNING' : 'DOWN',
                style: TextStyle(
                  color: active ? kGreenOn : kRedOn,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
