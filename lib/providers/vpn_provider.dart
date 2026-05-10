import 'dart:async';
import 'package:flutter/material.dart';
import '../models/peer_info.dart';
import '../models/server_status.dart';
import '../services/ssh_service.dart';
import '../services/vpn_service.dart';
import '../services/local_vpn_service.dart';

class VpnProvider extends ChangeNotifier {
  final SshService ssh = SshService();
  late final VpnService vpn = VpnService(ssh);
  final LocalVpnService localVpn = LocalVpnService();

  ServerStatus? _status;
  List<PeerInfo> _peers = [];
  bool _loading = false;
  String? _error;
  bool _initialized = false;
  Timer? _autoRefresh;
  Timer? _pingTimer;

  int? _pingMs;
  bool _vpnConnected = false;
  bool _pingInProgress = false;

  ServerStatus? get status => _status;
  List<PeerInfo> get peers => _peers;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConnected => ssh.isConnected;
  int? get pingMs => _pingMs;
  bool get vpnConnected => _vpnConnected;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await ssh.loadConfig();
    await localVpn.loadConfig();
    await refresh();
    await _updateLocalState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _doPing());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _pingTimer?.cancel();
    ssh.disconnect();
    super.dispose();
  }

  Future<void> _updateLocalState() async {
    _vpnConnected = await localVpn.isVpnConnected();
    notifyListeners();
  }

  Future<void> _doPing() async {
    if (_pingInProgress) return;
    _pingInProgress = true;
    _pingMs = await localVpn.pingServer();
    _pingInProgress = false;
    notifyListeners();
  }

  Future<void> doPingNow() => _doPing();

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _status = await vpn.getStatus();
      if (_status!.isReachable) {
        _peers = await vpn.getPeers();
      }
    } catch (e) {
      _error = e.toString();
      _status = ServerStatus.offline();
    } finally {
      _loading = false;
      notifyListeners();
    }
    _doPing();
    _updateLocalState();
  }

  Future<String> toggleVpn() async {
    final result = _vpnConnected
        ? await localVpn.disconnect()
        : await localVpn.connect();
    await Future.delayed(const Duration(seconds: 2));
    await _updateLocalState();
    return result;
  }

  Future<String> runControl(String label, Future<String> Function() action) async {
    _loading = true;
    notifyListeners();
    try {
      final result = await action();
      await Future.delayed(const Duration(seconds: 2));
      await refresh();
      return result;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return 'Error: $e';
    }
  }
}
