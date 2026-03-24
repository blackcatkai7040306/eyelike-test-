import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'config.dart';
import 'models/app_user.dart';
import 'models/chat_message.dart';
import 'supabase_config.dart';

class Session extends ChangeNotifier {
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

  StreamSubscription<AuthState>? _authSub;

  SupabaseClient? get _sb => supabaseAppReady ? Supabase.instance.client : null;

  String _peerUsername(String peerId) {
    for (final p in peers) {
      if (p.id == peerId) return p.username;
    }
    return '?';
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    serverBaseUrl = p.getString(_kServer) ?? defaultServerBaseUrl();

    if (supabaseAppReady) {
      _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final ev = data.event;
        if (ev == AuthChangeEvent.signedIn ||
            ev == AuthChangeEvent.tokenRefreshed ||
            ev == AuthChangeEvent.userUpdated) {
          unawaited(_afterAuthChange());
        }
        if (ev == AuthChangeEvent.signedOut) {
          disconnectSocket();
          user = null;
          token = null;
          peers = [];
          onlineIds = {};
          messagesByPeer.clear();
          notifyListeners();
        }
      });

      await _syncUserFromSupabase();
      if (user != null && token != null) {
        await connectSocket();
        await refreshPeers();
      }
    }
    notifyListeners();
  }

  Future<void> _afterAuthChange() async {
    await _syncUserFromSupabase();
    if (user != null && token != null) {
      await connectSocket();
      await refreshPeers();
    } else {
      disconnectSocket();
    }
    notifyListeners();
  }

  Future<void> _syncUserFromSupabase() async {
    final client = _sb;
    if (client == null) return;
    final authSession = client.auth.currentSession;
    if (authSession == null) {
      user = null;
      token = null;
      return;
    }
    token = authSession.accessToken;
    final uid = authSession.user.id;
    final profile = await client.from('profiles').select().eq('id', uid).maybeSingle();
    final uname = profile?['username'] as String? ??
        authSession.user.email?.split('@').first ??
        'user';
    user = AppUser(id: uid, username: uname);
  }

  Future<void> persistServer(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    serverBaseUrl = trimmed.isEmpty ? defaultServerBaseUrl() : trimmed;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, serverBaseUrl);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final client = _sb;
    if (client == null) {
      throw StateError('Supabase is not configured. Fill mobile/assets/env');
    }
    await client.auth.signInWithPassword(email: email.trim(), password: password);
    await _syncUserFromSupabase();
    await connectSocket();
    await refreshPeers();
    notifyListeners();
  }

  Future<void> register(String email, String password, String displayUsername) async {
    final client = _sb;
    if (client == null) {
      throw StateError('Supabase is not configured. Fill mobile/assets/env');
    }
    final u = displayUsername.trim();
    if (u.length < 2) {
      throw ArgumentError('Display name too short');
    }
    final res = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': u},
    );
    if (res.session == null) {
      throw StateError(
        'Check your email to confirm signup, or disable email confirmation in Supabase Auth settings.',
      );
    }
    await _syncUserFromSupabase();
    await connectSocket();
    await refreshPeers();
    notifyListeners();
  }

  Future<void> logout() async {
    disconnectSocket();
    await _sb?.auth.signOut();
    user = null;
    token = null;
    peers = [];
    onlineIds = {};
    messagesByPeer.clear();
    notifyListeners();
  }

  Future<void> refreshPeers() async {
    final client = _sb;
    final self = user?.id;
    if (client == null || self == null) return;
    final rows = await client.from('profiles').select().neq('id', self);
    final list = rows as List<dynamic>;
    peers = list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] as String;
      return PeerProfile(
        id: id,
        username: m['username'] as String? ?? '?',
        online: onlineIds.contains(id),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> loadMessagesForPeer(String peerId) async {
    final client = _sb;
    final self = user?.id;
    if (client == null || self == null) return;
    final peerName = _peerUsername(peerId);
    final myName = user?.username ?? '?';

    final filter =
        'and(from_id.eq.$self,to_id.eq.$peerId),and(from_id.eq.$peerId,to_id.eq.$self)';
    final rows = await client.from('messages').select().or(filter).order('created_at');

    final list = rows as List<dynamic>;
    final msgs = list.map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      return ChatMessage.fromMessageRow(
        row,
        selfId: self,
        peerUsername: peerName,
        myUsername: myName,
      );
    }).toList();
    messagesByPeer[peerId] = msgs;
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
      final id = m['id'] as String? ?? '';
      final bucket = messagesByPeer.putIfAbsent(other, () => []);
      if (id.isNotEmpty && bucket.any((x) => x.id == id)) {
        return;
      }
      final msg = ChatMessage.fromServer(m, selfId: self);
      bucket.add(msg);
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
    final client = _sb;
    final sock = socket;
    final self = user;
    if (client == null || self == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final row = await client
        .from('messages')
        .insert({
          'from_id': self.id,
          'to_id': toUserId,
          'body': trimmed,
        })
        .select()
        .single();

    final peerName = _peerUsername(toUserId);
    final msg = ChatMessage.fromMessageRow(
      Map<String, dynamic>.from(row),
      selfId: self.id,
      peerUsername: peerName,
      myUsername: self.username,
    );
    final bucket = messagesByPeer.putIfAbsent(toUserId, () => []);
    if (!bucket.any((x) => x.id == msg.id)) {
      bucket.add(msg);
    }
    notifyListeners();

    if (sock == null || !sock.connected) return;

    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    sock.emitWithAck(
      'chat:private',
      {
        'toUserId': toUserId,
        'text': trimmed,
        'messageId': msg.id,
        'at': msg.at,
        'clientNonce': nonce,
      },
      ack: (dynamic data, [dynamic _]) {
        if (data is Map && data['ok'] != true) {
          socketError = data['error']?.toString() ?? 'send failed';
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
    _authSub?.cancel();
    disconnectSocket();
    super.dispose();
  }
}
