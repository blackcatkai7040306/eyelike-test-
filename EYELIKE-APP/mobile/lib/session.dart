import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config.dart';
import 'models/app_user.dart';
import 'models/chat_message.dart';
import 'services/api_client.dart';

class Session extends ChangeNotifier {
  static const _kToken = 'eyelike_token';
  static const _kUser = 'eyelike_user_json';
  static const _kServer = 'eyelike_server';

  String serverBaseUrl = defaultServerBaseUrl();
  String? token;
  AppUser? user;
  io.Socket? socket;
  bool connecting = false;
  String? socketError;

  final Map<String, List<ChatMessage>> messagesByPeer = {};
  List<PeerProfile> peers = [];
  Set<String> onlineIds = {};

  ApiClient get api => ApiClient(baseUrl: serverBaseUrl);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    serverBaseUrl = p.getString(_kServer) ?? defaultServerBaseUrl();
    token = p.getString(_kToken);
    final raw = p.getString(_kUser);
    if (raw != null) {
      try {
        user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    if (token != null && user == null) {
      token = null;
      await p.remove(_kToken);
    }
    if (user != null && token != null) {
      await connectSocket();
      await refreshPeers();
    }
    notifyListeners();
  }

  Future<void> persistAuth(String t, AppUser u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, t);
    await p.setString(
      _kUser,
      jsonEncode({'id': u.id, 'username': u.username}),
    );
    token = t;
    user = u;
    notifyListeners();
  }

  Future<void> persistServer(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    serverBaseUrl = trimmed.isEmpty ? defaultServerBaseUrl() : trimmed;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, serverBaseUrl);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final body = await api.login(username: username, password: password);
    final u = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    final t = body['token'] as String;
    await persistAuth(t, u);
    await connectSocket();
    await refreshPeers();
  }

  Future<void> register(String username, String password) async {
    final body = await api.register(username: username, password: password);
    final u = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    final t = body['token'] as String;
    await persistAuth(t, u);
    await connectSocket();
    await refreshPeers();
  }

  Future<void> logout() async {
    disconnectSocket();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    token = null;
    user = null;
    peers = [];
    onlineIds = {};
    messagesByPeer.clear();
    notifyListeners();
  }

  Future<void> refreshPeers() async {
    if (token == null) return;
    peers = await api.fetchPeers(token!);
    notifyListeners();
  }

  Future<void> connectSocket() async {
    if (token == null) return;
    disconnectSocket();
    connecting = true;
    socketError = null;
    notifyListeners();

    final s = io.io(
      serverBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    s.onConnect((_) {
      connecting = false;
      socketError = null;
      notifyListeners();
    });
    s.onConnectError((dynamic e) {
      connecting = false;
      socketError = e.toString();
      notifyListeners();
    });
    s.onDisconnect((_) {
      connecting = false;
      notifyListeners();
    });

    s.on('chat:private', (data) {
      if (data is! Map) return;
      final m = Map<String, dynamic>.from(data);
      final self = user?.id;
      if (self == null) return;
      final other =
          m['fromUserId'] == self ? m['toUserId'] as String : m['fromUserId'] as String;
      final msg = ChatMessage.fromServer(m, selfId: self);
      messagesByPeer.putIfAbsent(other, () => []).add(msg);
      notifyListeners();
    });

    s.on('presence:update', (data) {
      if (data is! Map) return;
      final ids = data['onlineIds'];
      if (ids is List) {
        onlineIds = ids.map((e) => e.toString()).toSet();
        peers = peers
            .map(
              (p) => PeerProfile(
                id: p.id,
                username: p.username,
                online: onlineIds.contains(p.id),
              ),
            )
            .toList();
        notifyListeners();
      }
    });

    socket = s;
    s.connect();
    notifyListeners();
  }

  void disconnectSocket() {
    socket?.dispose();
    socket = null;
    connecting = false;
  }

  Future<void> sendPrivateMessage(String toUserId, String text) async {
    final s = socket;
    final self = user;
    if (s == null || self == null || !s.connected) return;
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    s.emitWithAck(
      'chat:private',
      {'toUserId': toUserId, 'text': text, 'clientNonce': nonce},
      ack: (dynamic data, [dynamic _]) {
        if (data is Map && data['ok'] == true && data['message'] != null) {
          final m = Map<String, dynamic>.from(data['message'] as Map);
          final msg = ChatMessage.fromServer(m, selfId: self.id);
          messagesByPeer.putIfAbsent(toUserId, () => []).add(msg);
          notifyListeners();
        }
      },
    );
  }

  void emitWebRtcSignal(String toUserId, Map<String, dynamic> payload) {
    final data = <String, dynamic>{'toUserId': toUserId}..addAll(payload);
    socket?.emit('webrtc:signal', data);
  }

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
