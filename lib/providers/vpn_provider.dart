import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
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
  StreamSubscription<VpnStage>? _stageSubscription;

  int? _pingMs;
  VpnStage _vpnStage = VpnStage.disconnected;
  bool _pingInProgress = false;

  ServerStatus? get status => _status;
  List<PeerInfo> get peers => _peers;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConnected => ssh.isConnected;
  int? get pingMs => _pingMs;
  VpnStage get vpnStage => _vpnStage;
  bool get vpnConnected => _vpnStage == VpnStage.connected;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await ssh.loadConfig();
    await localVpn.loadConfig();

    if (Platform.isIOS) {
      await localVpn.initialize();
      _stageSubscription = localVpn.stageStream.listen((stage) {
        _vpnStage = stage;
        notifyListeners();
      });
    }

    await refresh();

    if (!Platform.isIOS) {
      await _updateLocalVpnState();
      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _doPing());
    }

    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    _stageSubscription?.cancel();
    _autoRefresh?.cancel();
    _pingTimer?.cancel();
    ssh.disconnect();
    super.dispose();
  }

  Future<void> _updateLocalVpnState() async {
    final connected = await localVpn.isVpnConnected();
    _vpnStage = connected ? VpnStage.connected : VpnStage.disconnected;
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
    if (!Platform.isIOS) _updateLocalVpnState();
  }

  Future<String> toggleVpn() async {
    final result = vpnConnected
        ? await localVpn.disconnect()
        : await localVpn.connect();
    // iOS stage updates come via stream; macOS and Windows need a manual check
    if (!Platform.isIOS) {
      await Future.delayed(const Duration(seconds: 2));
      await _updateLocalVpnState();
    }
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
