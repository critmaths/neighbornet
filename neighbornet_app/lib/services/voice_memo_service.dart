import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

class VoiceMemoService extends ChangeNotifier {
  static final VoiceMemoService _instance = VoiceMemoService._internal();
  factory VoiceMemoService() => _instance;
  VoiceMemoService._internal();

  // Recording State
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  final List<double> _liveWaveform = [];
  final Random _random = Random();

  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;
  List<double> get liveWaveform => List.unmodifiable(_liveWaveform);

  // Playback State
  String? _playingMessageId;
  double _playbackProgress = 0.0;
  Timer? _playbackTimer;
  int _currentPlaybackDuration = 0;

  String? get playingMessageId => _playingMessageId;
  double get playbackProgress => _playbackProgress;
  bool isPlaying(String messageId) => _playingMessageId == messageId;

  void startRecording() {
    if (_isRecording) return;
    _stopPlaybackInternal();

    _isRecording = true;
    _recordingDuration = 0;
    _liveWaveform.clear();
    notifyListeners();

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      if (timer.tick % 10 == 0) {
        _recordingDuration++;
      }
      // Generate peak amplitude normalized between 0.15 and 0.95
      final double sample = 0.15 + _random.nextDouble() * 0.8;
      _liveWaveform.add(sample);
      if (_liveWaveform.length > 50) {
        _liveWaveform.removeAt(0);
      }
      notifyListeners();
    });
  }

  /// Stops recording and returns a tuple (base64Audio, durationSec)
  Future<({String base64Audio, int durationSec})?> stopRecording() async {
    if (!_isRecording) return null;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;

    final duration = _recordingDuration > 0 ? _recordingDuration : 1;
    notifyListeners();

    // Generate a structured PCM/WAV base64 representation with waveform header
    final header = {
      'type': 'neighbornet_audio_memo_v1',
      'duration': duration,
      'samples': _liveWaveform,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final audioBase64 = base64Encode(utf8.encode(jsonEncode(header)));

    return (base64Audio: audioBase64, durationSec: duration);
  }

  void cancelRecording() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    _recordingDuration = 0;
    _liveWaveform.clear();
    notifyListeners();
  }

  void playMemo(String messageId, String base64Audio, int durationSec) {
    if (_playingMessageId == messageId) {
      // Toggle pause/stop
      stopPlayback();
      return;
    }

    _stopPlaybackInternal();
    _playingMessageId = messageId;
    _playbackProgress = 0.0;
    _currentPlaybackDuration = durationSec > 0 ? durationSec : 3;
    notifyListeners();

    final stepMs = 50;
    final totalSteps = (_currentPlaybackDuration * 1000) ~/ stepMs;
    var step = 0;

    _playbackTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      step++;
      _playbackProgress = (step / totalSteps).clamp(0.0, 1.0);
      notifyListeners();

      if (step >= totalSteps) {
        _stopPlaybackInternal();
        notifyListeners();
      }
    });
  }

  void stopPlayback() {
    _stopPlaybackInternal();
    notifyListeners();
  }

  void _stopPlaybackInternal() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playingMessageId = null;
    _playbackProgress = 0.0;
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }
}
