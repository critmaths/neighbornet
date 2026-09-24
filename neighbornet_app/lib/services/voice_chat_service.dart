import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallState { idle, calling, ringing, connected, error }

typedef SignalSender = void Function(String targetPeerId, String type, Map<String, dynamic> data);

class VoiceChatService extends ChangeNotifier {
  CallState _state = CallState.idle;
  String _lastError = '';
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isCameraAvailable = false;

  String? _activePeerId;
  String? _activePeerNickname;
  String? _incomingOfferSdp;
  bool _incomingIsVideo = false;

  SignalSender? _signalSender;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  CallState get state => _state;
  String get lastError => _lastError;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isCameraAvailable => _isCameraAvailable;

  String? get activePeerId => _activePeerId;
  String? get activePeerNickname => _activePeerNickname;
  bool get incomingIsVideo => _incomingIsVideo;

  MediaStream? get localStream => _localStream;
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  VoiceChatService() {
    _initRenderers();
  }

  void setSignalSender(SignalSender sender) {
    _signalSender = sender;
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    } catch (e) {
      debugPrint('[VoiceChatService] Renderer initialization error: $e');
    }
  }

  void _setState(CallState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String errorMsg) {
    _lastError = errorMsg;
    _setState(CallState.error);

    // Automatically reset to idle after 4 seconds on error
    Future.delayed(const Duration(seconds: 4), () {
      if (_state == CallState.error) {
        _setState(CallState.idle);
      }
    });
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isPermanentlyDenied || status.isDenied) {
        _setError('Microphone permission denied.');
        return false;
      }
      return true;
    } catch (_) {
      return true; // Desktop fallback
    }
  }

  Future<bool> _requestCameraPermission() async {
    try {
      var status = await Permission.camera.request();
      if (status.isPermanentlyDenied || status.isDenied) {
        return false;
      }
      return true;
    } catch (_) {
      return true; // Desktop fallback
    }
  }

  Future<void> _initializeWebRTC() async {
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'url': 'stun:stun.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (_activePeerId != null && candidate.candidate != null) {
          _signalSender?.call(_activePeerId!, 'candidate', {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _setError('Call disconnected.');
          endCall(notifyRemote: false);
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _setState(CallState.connected);
        }
      };

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          _remoteRenderer.srcObject = event.streams.isNotEmpty ? event.streams[0] : null;
          notifyListeners();
        }
      };
    } catch (e) {
      _setError('Failed to initialize WebRTC engine: $e');
      rethrow;
    }
  }

  Future<void> _startLocalStream({bool withVideo = false}) async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': withVideo
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (_localStream!.getAudioTracks().isEmpty) {
        throw Exception('No microphone hardware found.');
      }

      _localStream!.getAudioTracks()[0].enabled = !_isMuted;

      if (withVideo && _localStream!.getVideoTracks().isNotEmpty) {
        _localRenderer.srcObject = _localStream;
        _isVideoEnabled = true;
        _isCameraAvailable = true;
      }

      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    } catch (e) {
      // If video requested but failed (camera busy/not found), fallback cleanly to audio-only
      if (withVideo) {
        debugPrint('[VoiceChatService] Camera unavailable, falling back to audio only: $e');
        _isVideoEnabled = false;
        _isCameraAvailable = false;
        await _startLocalStream(withVideo: false);
        return;
      }

      if (e.toString().contains('NotReadableError') || e.toString().contains('NotFoundError')) {
        _setError('No microphone hardware exists or it is currently in use.');
      } else {
        _setError('Could not access audio device: $e');
      }
      rethrow;
    }
  }

  Future<void> startCall(String peerId, {String? peerNickname, bool withVideo = false}) async {
    _lastError = '';
    _activePeerId = peerId;
    _activePeerNickname = peerNickname ?? peerId;
    _incomingOfferSdp = null;

    bool hasMic = await _requestMicrophonePermission();
    if (!hasMic) return;

    if (withVideo) {
      await _requestCameraPermission();
    }

    _setState(CallState.calling);

    try {
      await _initializeWebRTC();
      await _startLocalStream(withVideo: withVideo);

      RTCSessionDescription offer = await _peerConnection!.createOffer({});
      await _peerConnection!.setLocalDescription(offer);

      // Send offer through signaling
      _signalSender?.call(peerId, 'offer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'withVideo': withVideo,
        'callerNickname': _activePeerNickname,
      });

      // Stay in calling until answer received, or connected
      _setState(CallState.calling);
    } catch (e) {
      endCall();
    }
  }

  void handleIncomingOffer({
    required String callerId,
    required String callerNickname,
    required String sdpOffer,
    required bool withVideo,
  }) {
    if (_state != CallState.idle) {
      // Busy: decline automatically
      _signalSender?.call(callerId, 'busy', {});
      return;
    }

    _activePeerId = callerId;
    _activePeerNickname = callerNickname;
    _incomingOfferSdp = sdpOffer;
    _incomingIsVideo = withVideo;
    _setState(CallState.ringing);
  }

  Future<void> answerCall({bool withVideo = false}) async {
    if (_state != CallState.ringing || _incomingOfferSdp == null || _activePeerId == null) {
      return;
    }

    _lastError = '';

    bool hasMic = await _requestMicrophonePermission();
    if (!hasMic) {
      declineCall();
      return;
    }

    if (withVideo) {
      await _requestCameraPermission();
    }

    try {
      await _initializeWebRTC();
      await _startLocalStream(withVideo: withVideo);

      final description = RTCSessionDescription(_incomingOfferSdp!, 'offer');
      await _peerConnection!.setRemoteDescription(description);

      final answer = await _peerConnection!.createAnswer({});
      await _peerConnection!.setLocalDescription(answer);

      // Send answer through signaling
      _signalSender?.call(_activePeerId!, 'answer', {
        'sdp': answer.sdp,
        'type': answer.type,
      });

      _setState(CallState.connected);
    } catch (e) {
      _setError('Error answering call: $e');
      endCall();
    }
  }

  Future<void> handleIncomingAnswer(String sdpAnswer) async {
    try {
      if (_peerConnection != null) {
        final description = RTCSessionDescription(sdpAnswer, 'answer');
        await _peerConnection!.setRemoteDescription(description);
        _setState(CallState.connected);
      }
    } catch (e) {
      debugPrint('[VoiceChatService] Error applying answer: $e');
    }
  }

  Future<void> handleIncomingCandidate(Map<String, dynamic> candidateMap) async {
    try {
      if (_peerConnection != null) {
        final candidate = RTCIceCandidate(
          candidateMap['candidate'] as String?,
          candidateMap['sdpMid'] as String?,
          candidateMap['sdpMLineIndex'] as int?,
        );
        await _peerConnection!.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('[VoiceChatService] Error adding ICE candidate: $e');
    }
  }

  void declineCall() {
    if (_activePeerId != null) {
      _signalSender?.call(_activePeerId!, 'hangup', {});
    }
    endCall(notifyRemote: false);
  }

  void handleHangup() {
    _setError('Call ended by peer.');
    endCall(notifyRemote: false);
  }

  Future<void> toggleVideo() async {
    if (_state != CallState.connected) return;

    if (_isVideoEnabled) {
      for (var track in _localStream?.getVideoTracks() ?? []) {
        track.stop();
        _localStream?.removeTrack(track);
      }
      _localRenderer.srcObject = null;
      _isVideoEnabled = false;
      notifyListeners();
    } else {
      try {
        final Map<String, dynamic> videoConstraints = {
          'audio': false,
          'video': {
            'mandatory': {'minWidth': '640', 'minHeight': '480'},
            'facingMode': 'user',
          }
        };

        final videoStream = await navigator.mediaDevices.getUserMedia(videoConstraints);
        if (videoStream.getVideoTracks().isNotEmpty) {
          final videoTrack = videoStream.getVideoTracks()[0];
          _localStream?.addTrack(videoTrack);
          _peerConnection?.addTrack(videoTrack, _localStream!);
          _localRenderer.srcObject = _localStream;
          _isVideoEnabled = true;
          _isCameraAvailable = true;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[VoiceChatService] Failed to enable camera: $e');
        _isVideoEnabled = false;
        _isCameraAvailable = false;
        _lastError = 'Camera not available or access denied. Audio call remains active.';
        notifyListeners();
      }
    }
  }

  void endCall({bool notifyRemote = true}) {
    if (notifyRemote && _activePeerId != null && _state != CallState.idle) {
      _signalSender?.call(_activePeerId!, 'hangup', {});
    }

    _activePeerId = null;
    _activePeerNickname = null;
    _incomingOfferSdp = null;

    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;
    try {
      _localRenderer.srcObject = null;
    } catch (_) {}
    try {
      _remoteRenderer.srcObject = null;
    } catch (_) {}

    _peerConnection?.close();
    _peerConnection = null;

    _isMuted = false;
    _isVideoEnabled = false;

    if (_state != CallState.error) {
      _setState(CallState.idle);
    } else {
      notifyListeners();
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    endCall(notifyRemote: false);
    try {
      _localRenderer.dispose();
    } catch (_) {}
    try {
      _remoteRenderer.dispose();
    } catch (_) {}
    super.dispose();
  }
}
