import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_user.dart';
import '../session.dart';
import '../theme/eyelike_theme.dart';
import '../webrtc/peer_link.dart';
import '../widgets/optic_mesh_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session, required this.peer});

  final Session session;
  final PeerProfile peer;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  PeerLink? _link;
  bool _inCall = false;
  bool _starting = false;
  late void Function(dynamic) _rtcHandler;

  Session get s => widget.session;
  String get peerId => widget.peer.id;

  void _onSession() => setState(() {});

  @override
  void initState() {
    super.initState();
    s.addListener(_onSession);
    unawaited(s.loadMessagesForPeer(peerId));
    _rtcHandler = (dynamic raw) {
      unawaited(_handleIncomingRtc(raw));
    };
    s.socket?.on('webrtc:signal', _rtcHandler);
  }

  Future<void> _handleIncomingRtc(dynamic raw) async {
    if (raw is! Map) return;
    final from = raw['fromUserId']?.toString();
    if (from != peerId) return;
    final type = raw['type']?.toString();
    if (type == null) return;

    final link = _link ??= PeerLink(
      sendSignal: (t, body) => s.emitWebRtcSignal(peerId, {'type': t, ...body}),
    );

    if (type == 'offer') {
      if (!await _ensureMediaPermissions()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incoming call — allow camera & mic to answer')),
          );
        }
        return;
      }
      if (mounted) setState(() => _inCall = true);
    }

    try {
      if (type == 'offer') {
        await link.handleRemote('offer', {'sdp': raw['sdp']});
      } else if (type == 'answer') {
        await link.handleRemote('answer', {'sdp': raw['sdp']});
      } else if (type == 'ice') {
        await link.handleRemote('ice', {
          'candidate': raw['candidate'],
          'sdpMid': raw['sdpMid'],
          'sdpMLineIndex': raw['sdpMLineIndex'],
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WebRTC: $e')));
      }
    }
    if (mounted) setState(() {});
  }

  Future<bool> _ensureMediaPermissions() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return cam.isGranted && mic.isGranted;
  }

  Future<void> _startCall() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      if (!await _ensureMediaPermissions()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera & microphone permission required')),
          );
        }
        return;
      }
      final link = _link ??= PeerLink(
        sendSignal: (t, body) => s.emitWebRtcSignal(peerId, {'type': t, ...body}),
      );
      setState(() => _inCall = true);
      await link.startCaller();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _inCall = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _endCall() async {
    await _link?.dispose();
    _link = null;
    setState(() => _inCall = false);
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    s.sendPrivateMessage(peerId, t);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    s.removeListener(_onSession);
    s.socket?.off('webrtc:signal', _rtcHandler);
    _link?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = s.messagesByPeer[peerId] ?? const [];
    return Scaffold(
      body: OpticMeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EyelikeColors.cyan),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(widget.peer.username, style: titleEyelike(18)),
                        subtitle: Text(
                          widget.peer.online ? 'online · optic channel' : 'offline · messages queue when back',
                          style: const TextStyle(color: EyelikeColors.dim, fontSize: 11),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _starting ? null : (_inCall ? _endCall : _startCall),
                      icon: Icon(_inCall ? Icons.call_end_rounded : Icons.videocam_rounded,
                          size: 20, color: _inCall ? EyelikeColors.magenta : EyelikeColors.cyan),
                      label: Text(_inCall ? 'End' : 'Call'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment:
                                m.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14).copyWith(
                                      bottomRight: m.mine ? const Radius.circular(4) : null,
                                      bottomLeft: !m.mine ? const Radius.circular(4) : null,
                                    ),
                                    color: m.mine
                                        ? EyelikeColors.cyan.withValues(alpha: 0.18)
                                        : EyelikeColors.panel.withValues(alpha: 0.95),
                                    border: Border.all(
                                      color: m.mine
                                          ? EyelikeColors.cyan.withValues(alpha: 0.35)
                                          : EyelikeColors.magenta.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    m.text,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_inCall && _link != null)
                      Positioned.fill(
                        child: Container(
                          color: EyelikeColors.voidBlack.withValues(alpha: 0.94),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RTCVideoView(
                                  _link!.remoteRenderer,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  width: 112,
                                  height: 160,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: RTCVideoView(
                                      _link!.localRenderer,
                                      mirror: true,
                                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        backgroundColor: EyelikeColors.cyan,
                        foregroundColor: EyelikeColors.voidBlack,
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
