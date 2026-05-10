import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_card.dart';
import '../widgets/steam_button.dart';
import '../widgets/steam_gauge.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<_LogLine> _lines = [];
  StreamSubscription<String>? _sub;
  bool _streaming = false;
  bool _autoScroll = true;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _start(VpnProvider prov) {
    if (_streaming) return;
    setState(() {
      _streaming = true;
      _lines.clear();
    });
    _sub = prov.vpn.getLogs().listen(
      (chunk) {
        final newLines = chunk.split('\n').where((l) => l.isNotEmpty).map(
              (l) => _LogLine(text: l, time: DateTime.now()),
            );
        setState(() {
          _lines.addAll(newLines);
          if (_lines.length > 1000) _lines.removeRange(0, _lines.length - 1000);
        });
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
      },
      onError: (e) {
        setState(() {
          _lines.add(_LogLine(text: 'STREAM ERROR: $e', time: DateTime.now(), isError: true));
          _streaming = false;
        });
      },
      onDone: () => setState(() => _streaming = false),
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    setState(() => _streaming = false);
  }

  void _clear() => setState(() => _lines.clear());

  void _copyAll() {
    final text = _lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<VpnProvider>();

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              const SteamLabel('Docker Logs — wg-easy'),
              const Spacer(),
              if (_streaming) ...[
                const GearSpinner(size: 18),
                const SizedBox(width: 8),
              ],
              SteamButton(
                label: _streaming ? 'Stop' : 'Stream',
                icon: _streaming ? Icons.stop : Icons.play_arrow,
                small: true,
                danger: _streaming,
                onPressed: () => _streaming ? _stop() : _start(prov),
              ),
              const SizedBox(width: 8),
              SteamButton(
                label: 'Clear',
                icon: Icons.delete_outline,
                small: true,
                onPressed: _clear,
              ),
              const SizedBox(width: 8),
              SteamButton(
                label: 'Copy',
                icon: Icons.copy,
                small: true,
                onPressed: _copyAll,
              ),
            ],
          ),
        ),

        // Auto-scroll toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _autoScroll = !_autoScroll),
                child: Row(
                  children: [
                    Icon(
                      _autoScroll ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 14,
                      color: kBrass,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Auto-scroll',
                      style: TextStyle(color: kParchDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_lines.length} lines',
                style: const TextStyle(color: kParchDim, fontSize: 10),
              ),
            ],
          ),
        ),

        // Log content
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            decoration: BoxDecoration(
              color: kTermBg,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            child: _lines.isEmpty
                ? Center(
                    child: Text(
                      _streaming
                          ? 'Waiting for log data...'
                          : 'Press STREAM to begin',
                      style: const TextStyle(color: kParchDim, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(10),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) {
                      final line = _lines[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${_ts(line.time)} ',
                                style: const TextStyle(
                                  color: kParchDim,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              TextSpan(
                                text: line.text,
                                style: TextStyle(
                                  color: line.isError
                                      ? kRedOn
                                      : line.text.toLowerCase().contains('error')
                                          ? kRedOn
                                          : line.text.toLowerCase().contains('warn')
                                              ? kBrassLight
                                              : kTermText,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _ts(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _LogLine {
  final String text;
  final DateTime time;
  final bool isError;

  _LogLine({required this.text, required this.time, this.isError = false});
}
