import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_card.dart';
import '../widgets/steam_button.dart';
import '../widgets/steam_gauge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _host;
  late TextEditingController _port;
  late TextEditingController _user;
  late TextEditingController _keyPath;
  late TextEditingController _keyContent;
  late TextEditingController _tunnelName;
  late TextEditingController _wgConfig;
  bool _saved = false;
  bool _wgSaved = false;
  bool _testing = false;
  String? _testResult;
  String? _repairResult;

  @override
  void initState() {
    super.initState();
    final prov = context.read<VpnProvider>();
    final ssh = prov.ssh;
    _host = TextEditingController(text: ssh.host);
    _port = TextEditingController(text: ssh.port.toString());
    _user = TextEditingController(text: ssh.username);
    _keyPath = TextEditingController(text: ssh.keyPath ?? _defaultKeyPath());
    _keyContent = TextEditingController(text: ssh.keyContent ?? '');
    _tunnelName = TextEditingController(text: prov.localVpn.tunnelName);
    _wgConfig = TextEditingController(text: prov.localVpn.wgConfig);
  }

  String _defaultKeyPath() {
    if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}\\.ssh\\id_ed25519';
    }
    return '${Platform.environment['HOME']}/.ssh/id_ed25519';
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _keyPath.dispose();
    _keyContent.dispose();
    _tunnelName.dispose();
    _wgConfig.dispose();
    super.dispose();
  }

  Future<void> _repairMacTunnel() async {
    final prov = context.read<VpnProvider>();
    final msg = await prov.localVpn.repairMacTunnel();
    setState(() => _repairResult = msg);
  }

  Future<void> _saveWgConfig() async {
    final prov = context.read<VpnProvider>();
    await prov.localVpn.saveConfig(
      tunnelName: _tunnelName.text.trim(),
      config: _wgConfig.text.trim(),
    );
    setState(() => _wgSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _wgSaved = false);
    });
  }

  Future<void> _save() async {
    final prov = context.read<VpnProvider>();
    await prov.ssh.saveConfig(
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 22,
      username: _user.text.trim(),
      keyPath: _keyPath.text.trim().isEmpty ? null : _keyPath.text.trim(),
      keyContent: _keyContent.text.trim().isEmpty ? null : _keyContent.text.trim(),
    );
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final prov = context.read<VpnProvider>();
      await prov.ssh.disconnect();
      final result = await prov.ssh.run('echo "Connection OK: \$(hostname)"');
      setState(() => _testResult = 'SUCCESS: $result');
    } catch (e) {
      setState(() => _testResult = 'FAILED: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SteamLabel('SSH Configuration'),
          const SizedBox(height: 16),

          SteamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Field(
                        label: 'Server Host',
                        controller: _host,
                        hint: '45.76.177.181',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Port',
                        controller: _port,
                        hint: '22',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Username',
                  controller: _user,
                  hint: 'root',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SteamLabel('Authentication'),
          const SizedBox(height: 12),

          SteamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  label: 'Private Key Path (Desktop)',
                  controller: _keyPath,
                  hint: _defaultKeyPath(),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Or paste key content below (required for iOS)',
                  style: TextStyle(color: kParchDim, fontSize: 10),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Private Key Content (paste PEM)',
                  controller: _keyContent,
                  hint: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                  maxLines: 6,
                  monospace: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              SteamButton(
                label: _saved ? 'Saved!' : 'Save Config',
                icon: _saved ? Icons.check : Icons.save,
                onPressed: _save,
              ),
              const SizedBox(width: 12),
              if (_testing)
                const GearSpinner(size: 24)
              else
                SteamButton(
                  label: 'Test Connection',
                  icon: Icons.cable,
                  onPressed: _test,
                ),
            ],
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 16),
            SteamCard(
              borderColor: _testResult!.startsWith('SUCCESS') ? kGreenDim : kRedDim,
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('SUCCESS') ? kGreenOn : kRedOn,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),
          const SteamLabel('Local WireGuard Tunnel'),
          const SizedBox(height: 4),
          const Text(
            'Used by the Connect/Disconnect toggle on the dashboard.',
            style: TextStyle(color: kParchDim, fontSize: 10),
          ),
          const SizedBox(height: 12),
          SteamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  label: 'Tunnel Name',
                  controller: _tunnelName,
                  hint: 'Michaels-PC',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'WireGuard Config (paste full .conf contents)',
                  controller: _wgConfig,
                  hint: '[Interface]\nPrivateKey = ...',
                  maxLines: 10,
                  monospace: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SteamCard(
            child: Consumer<VpnProvider>(
              builder: (context, prov, _) => Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'WebSocket Tunnel Mode',
                          style: TextStyle(color: kParchment, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tunnels over TCP — use on Myanmar networks or any ISP that blocks UDP.',
                          style: TextStyle(color: kParchDim, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: prov.localVpn.wsTunnelEnabled,
                    activeColor: kBrass,
                    onChanged: (v) => prov.localVpn.setWsTunnel(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SteamButton(
                label: _wgSaved ? 'Saved!' : 'Save Tunnel Config',
                icon: _wgSaved ? Icons.check : Icons.save,
                onPressed: _saveWgConfig,
              ),
              if (Platform.isMacOS) ...[
                const SizedBox(width: 12),
                SteamButton(
                  label: 'Repair Tunnel',
                  icon: Icons.build,
                  onPressed: _repairMacTunnel,
                ),
              ],
            ],
          ),
          if (_repairResult != null) ...[
            const SizedBox(height: 12),
            SteamCard(
              child: Text(
                _repairResult!,
                style: const TextStyle(color: kParchment, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 30),
          const SteamLabel('Server Info'),
          const SizedBox(height: 12),
          SteamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _InfoRow('Provider', 'Vultr · Singapore'),
                _InfoRow('OS', 'Ubuntu 24.04 LTS'),
                _InfoRow('Specs', '1 vCPU · 1GB RAM · 25GB SSD'),
                _InfoRow('WireGuard Port', 'UDP 443'),
                _InfoRow('Admin Panel', 'http://10.8.0.1:51821 (via VPN)'),
                _InfoRow('WG Subnet', '10.8.0.0/24'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool monospace;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: kBrassLight, fontSize: 9, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            color: kParchment,
            fontSize: 13,
            fontFamily: monospace ? 'monospace' : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kParchDim, fontSize: 12),
            filled: true,
            fillColor: kBgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: kBrass),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: kParchDim, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: kParchment, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
