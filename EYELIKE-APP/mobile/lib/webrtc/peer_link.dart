import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Minimal 1-on-1 WebRTC session (signaling is out of band).
class PeerLink {
  PeerLink({
    required this.sendSignal,
  });

  final void Function(String type, Map<String, dynamic> body) sendSignal;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final List<RTCIceCandidate> _pendingIce = [];
  bool _hasRemote = false;

  bool active = false;
  bool _renderersReady = false;

  Future<void> initRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Map<String, dynamic> get _rtcConfig => {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

  Future<void> _ensurePc() async {
    if (_pc != null) return;
    _pc = await createPeerConnection(_rtcConfig);
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };
    _pc!.onIceCandidate = (RTCIceCandidate? c) {
      if (c == null || c.candidate == null) return;
      sendSignal('ice', {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
  }

  Future<void> startCaller() async {
    await initRenderers();
    await _ensurePc();
    active = true;
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
    });
    localRenderer.srcObject = _local;
    for (final t in _local!.getTracks()) {
      await _pc!.addTrack(t, _local!);
    }
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    sendSignal('offer', {'sdp': offer.sdp});
  }

  Future<void> handleRemote(String type, Map<String, dynamic> data) async {
    if (type == 'offer') {
      await initRenderers();
      await _ensurePc();
      active = true;
      final sdp = data['sdp'] as String?;
      if (sdp == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _hasRemote = true;
      await _drainIce();

      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });
      localRenderer.srcObject = _local;
      for (final t in _local!.getTracks()) {
        await _pc!.addTrack(t, _local!);
      }

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      sendSignal('answer', {'sdp': answer.sdp});
      return;
    }

    if (type == 'answer') {
      final sdp = data['sdp'] as String?;
      if (sdp == null || _pc == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      _hasRemote = true;
      await _drainIce();
      return;
    }

    if (type == 'ice') {
      final cand = data['candidate'] as String?;
      if (cand == null) return;
      final mid = data['sdpMid'] as String?;
      final idxRaw = data['sdpMLineIndex'];
      final idx = idxRaw is int ? idxRaw : (idxRaw is num ? idxRaw.toInt() : null);
      final ice = RTCIceCandidate(cand, mid, idx);
      if (!_hasRemote || _pc == null) {
        _pendingIce.add(ice);
      } else {
        await _pc!.addCandidate(ice);
      }
    }
  }

  Future<void> _drainIce() async {
    if (_pc == null) return;
    for (final c in _pendingIce) {
      await _pc!.addCandidate(c);
    }
    _pendingIce.clear();
  }

  Future<void> dispose() async {
    active = false;
    _hasRemote = false;
    final loc = _local;
    if (loc != null) {
      for (final t in loc.getTracks()) {
        await t.stop();
      }
      await loc.dispose();
    }
    _local = null;
    await _pc?.close();
    _pc = null;
    if (_renderersReady) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _renderersReady = false;
    }
    _pendingIce.clear();
  }
}
