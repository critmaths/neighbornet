import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallState { idle, calling, ringing, connected, error }

class VoiceChatService extends ChangeNotifier {
  CallState _state = CallState.idle;
  String _lastError = '';
  bool _isMuted = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  CallState get state => _state;
  String get lastError => _lastError;
  bool get isMuted => _isMuted;
  
  MediaStream? get localStream => _localStream;

  void _setState(CallState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String errorMsg) {
    _lastError = errorMsg;
    _setState(CallState.error);
    
    // Automatically reset to idle after 3 seconds on error
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == CallState.error) {
        _setState(CallState.idle);
      }
    });
  }

  Future<bool> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status.isPermanentlyDenied || status.isDenied) {
      _setError('Microphone permission denied.');
      return false;
    }
    return true;
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
        // Simple signaling step would go here
      };
      
      _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _setError('Call dropped unexpectedly.');
          endCall();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _setState(CallState.connected);
        }
      };

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        // For voice only, WebRTC automatically handles the incoming audio track
      };

    } catch (e) {
      _setError('Failed to initialize WebRTC: $e');
      rethrow;
    }
  }

  Future<void> _startLocalStream() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (_localStream!.getAudioTracks().isEmpty) {
        throw Exception('No microphone hardware found or available.');
      }
      
      _localStream!.getAudioTracks()[0].enabled = !_isMuted;
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
      
    } catch (e) {
      if (e.toString().contains('NotReadableError') || e.toString().contains('NotFoundError')) {
        _setError('No microphone hardware exists or it is currently in use.');
      } else {
        _setError('Could not access microphone: $e');
      }
      rethrow;
    }
  }

  Future<void> startCall(String peerId) async {
    _lastError = '';
    
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    _setState(CallState.calling);
    
    try {
      await _initializeWebRTC();
      await _startLocalStream();
      
      RTCSessionDescription offer = await _peerConnection!.createOffer({});
      await _peerConnection!.setLocalDescription(offer);
      
      // Dummy logic to immediately connect for test mode
      _setState(CallState.connected);
    } catch (e) {
      endCall();
    }
  }

  Future<void> answerCall() async {
    _lastError = '';
    
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    try {
      await _initializeWebRTC();
      await _startLocalStream();
      
      _setState(CallState.connected);
    } catch (e) {
      endCall();
    }
  }

  void endCall() {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;

    _peerConnection?.close();
    _peerConnection = null;

    _isMuted = false;
    
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
    endCall();
    super.dispose();
  }
}
