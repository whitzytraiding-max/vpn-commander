import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SshService {
  SSHClient? _client;
  bool _connecting = false;

  String _host = '45.76.177.181';
  int _port = 22;
  String _username = 'root';
  String? _keyContent;
  String? _keyPath;

  String get host => _host;
  int get port => _port;
  String get username => _username;
  String? get keyPath => _keyPath;
  String? get keyContent => _keyContent;

  bool get isConnected {
    if (_client == null) return false;
    try {
      return !_client!.isClosed;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('ssh_host') ?? '45.76.177.181';
    _port = prefs.getInt('ssh_port') ?? 22;
    _username = prefs.getString('ssh_username') ?? 'root';
    _keyPath = prefs.getString('ssh_key_path');
    _keyContent = prefs.getString('ssh_key_content');
  }

  Future<void> saveConfig({
    required String host,
    required int port,
    required String username,
    String? keyPath,
    String? keyContent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssh_host', host);
    await prefs.setInt('ssh_port', port);
    await prefs.setString('ssh_username', username);
    if (keyPath != null) await prefs.setString('ssh_key_path', keyPath);
    if (keyContent != null) await prefs.setString('ssh_key_content', keyContent);
    _host = host;
    _port = port;
    _username = username;
    _keyPath = keyPath ?? _keyPath;
    _keyContent = keyContent ?? _keyContent;
    await disconnect();
  }

  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;
    try {
      await _doConnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _doConnect() async {
    final socket = await SSHSocket.connect(
      _host, _port,
      timeout: const Duration(seconds: 10),
    );

    String? keyData = _keyContent;

    if (keyData == null && _keyPath != null && _keyPath!.isNotEmpty) {
      final f = File(_keyPath!);
      if (await f.exists()) keyData = await f.readAsString();
    }

    if (keyData == null) {
      final candidates = <String>[
        if (Platform.isWindows)
          '${Platform.environment['USERPROFILE']}\\.ssh\\id_ed25519',
        if (Platform.isMacOS || Platform.isLinux)
          '${Platform.environment['HOME']}/.ssh/id_ed25519',
      ];
      for (final path in candidates) {
        final f = File(path);
        if (await f.exists()) {
          keyData = await f.readAsString();
          break;
        }
      }
    }

    _client = SSHClient(
      socket,
      username: _username,
      identities: keyData != null ? SSHKeyPair.fromPem(keyData) : [],
    );
  }

  Future<String> run(String command) async {
    if (!isConnected) {
      await connect();
    }
    try {
      return await _execute(command);
    } catch (e) {
      // Connection dropped — reconnect once
      _client = null;
      await connect();
      return await _execute(command);
    }
  }

  Future<String> _execute(String command) async {
    final session = await _client!.execute(command);
    final out = await utf8.decoder.bind(session.stdout).join();
    final err = await utf8.decoder.bind(session.stderr).join();
    await session.done;
    return out.isNotEmpty ? out.trim() : err.trim();
  }

  Stream<String> runStream(String command) async* {
    if (!isConnected) await connect();
    final session = await _client!.execute(command);
    await for (final chunk in session.stdout) {
      yield utf8.decode(chunk);
    }
    await session.done;
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
  }
}
