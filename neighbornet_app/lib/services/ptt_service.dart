import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/neighbornet_models.dart';
import 'neighbornet_bridge.dart';

enum PttState {
  idle,
  transmitting,
  receiving,
  busy,
}

class PttService extends ChangeNotifier {
  final NeighborNetBridge? bridge;
  NeighborNetBridge? get _bridge => bridge;

  PttState _state = PttState.idle;
  PttChannelInfo _activeChannel = kStandardPttChannels[0];
  final List<PttChannelInfo> _availableChannels = List.unmodifiable(kStandardPttChannels);

  String? _activeSpeakerNickname;
  String? _activeSpeakerCallsign;
  String? _activeSpeakerHash;
  String? _activeSpeakerSessionId;

  int _txSeconds = 0;
  Timer? _txTimer;
  Timer? _txChunkTimer;
  Timer? _rxWatchdogTimer;
  Timer? _vuAnimationTimer;
  Timer? _rogerBeepTimer;

  double _vuMeterLevel = 0.0;
  bool _voxEnabled = false;
  double _squelchLevel = 0.2;
  double _volume = 0.8;
  bool _rogerBeepEnabled = true;
  bool _recentRogerBeep = false;
  String? _lastError;

  String? _currentTxSessionId;
  int _currentTxSequence = 0;
  final List<String> _currentTxChunks = [];

  final List<PttTransmissionLog> _transmissionLogs = [];

  PttService({this.bridge});

  // --- GETTERS ---
  PttState get state => _state;
  PttChannelInfo get activeChannel => _activeChannel;
  List<PttChannelInfo> get availableChannels => _availableChannels;
  bool get isTransmitting => _state == PttState.transmitting;
  bool get isReceiving => _state == PttState.receiving;
  bool get isFloorBusy => _state == PttState.busy;
  bool get isIdle => _state == PttState.idle;

  String? get activeSpeakerNickname => _activeSpeakerNickname;
  String? get activeSpeakerCallsign => _activeSpeakerCallsign;
  String? get activeSpeakerHash => _activeSpeakerHash;
  String? get activeSpeakerSessionId => _activeSpeakerSessionId;

  int get txSeconds => _txSeconds;
  double get vuMeterLevel => _vuMeterLevel;
  bool get voxEnabled => _voxEnabled;
  double get squelchLevel => _squelchLevel;
  double get volume => _volume;
  bool get rogerBeepEnabled => _rogerBeepEnabled;
  bool get recentRogerBeep => _recentRogerBeep;
  String? get lastError => _lastError;
  List<PttTransmissionLog> get transmissionLogs => List.unmodifiable(_transmissionLogs);

  // --- CHANNEL SELECTION ---
  void selectChannel(PttChannelInfo channel) {
    if (_state == PttState.transmitting) {
      releasePtt();
    }
    _activeChannel = channel;
    _state = PttState.idle;
    _activeSpeakerNickname = null;
    _activeSpeakerCallsign = null;
    _activeSpeakerHash = null;
    _activeSpeakerSessionId = null;
    _vuMeterLevel = 0.0;
    notifyListeners();
  }

  void selectChannelById(String channelId) {
    final match = _availableChannels.firstWhere(
      (c) => c.id.toUpperCase() == channelId.toUpperCase(),
      orElse: () => _availableChannels[0],
    );
    selectChannel(match);
  }

  // --- PTT FLOOR CONTROL & TRANSMISSION ---
  bool pressPtt({bool isEmergencyOverride = false}) {
    if (_state == PttState.transmitting) return true;

    // Check if floor is held by someone else on this channel
    if (_state == PttState.receiving && !isEmergencyOverride && !_activeChannel.isEmergency) {
      _state = PttState.busy;
      _lastError = 'Channel floor is busy (${_activeSpeakerCallsign ?? _activeSpeakerNickname ?? "Remote"})';
      notifyListeners();
      return false;
    }

    _lastError = null;
    _state = PttState.transmitting;
    _txSeconds = 0;
    _currentTxSequence = 0;
    _currentTxChunks.clear();
    _currentTxSessionId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    // Broadcast floor claim to the mesh
    final priority = (isEmergencyOverride || _activeChannel.isEmergency) ? 'emergency' : 'normal';
    _bridge?.sendPttFloor(
      channel: _activeChannel.id,
      isTransmitting: true,
      priority: priority,
    );

    // Start TX duration counter
    _txTimer?.cancel();
    _txTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _txSeconds++;
      notifyListeners();
    });

    // Start chunk broadcaster (every 250ms)
    _txChunkTimer?.cancel();
    _txChunkTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      _broadcastNextTxChunk(isFinal: false);
    });

    // Animate VU meter with realistic voice fluctuations
    _startVuAnimation(transmitting: true);

    notifyListeners();
    return true;
  }

  void releasePtt() {
    if (_state != PttState.transmitting) return;

    _txTimer?.cancel();
    _txChunkTimer?.cancel();
    _stopVuAnimation();

    // Broadcast final chunk
    _broadcastNextTxChunk(isFinal: true);

    // Broadcast floor release
    _bridge?.sendPttFloor(
      channel: _activeChannel.id,
      isTransmitting: false,
      priority: _activeChannel.isEmergency ? 'emergency' : 'normal',
    );

    // Save transmission to local log
    final myProfile = _bridge?.getMyProfile();
    final log = PttTransmissionLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentTxSessionId ?? '',
      channel: _activeChannel.id,
      senderHash: myProfile?.destHash ?? 'local',
      senderNickname: myProfile?.nickname ?? 'Me',
      senderCallsign: myProfile?.callsign ?? 'LOCAL',
      durationSec: _txSeconds > 0 ? _txSeconds : 1,
      chunkCount: _currentTxSequence,
      priority: _activeChannel.isEmergency ? 'emergency' : 'normal',
      timestampSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      audioChunks: List.from(_currentTxChunks),
    );
    _transmissionLogs.insert(0, log);
    if (_transmissionLogs.length > 50) {
      _transmissionLogs.removeLast();
    }

    _currentTxSessionId = null;
    _currentTxSequence = 0;
    _currentTxChunks.clear();
    _txSeconds = 0;
    _state = PttState.idle;
    _vuMeterLevel = 0.0;

    // Trigger Roger Beep
    if (_rogerBeepEnabled) {
      _triggerRogerBeep();
    }

    notifyListeners();
  }

  void _broadcastNextTxChunk({required bool isFinal}) {
    _currentTxSequence++;
    // Generate synthetic audio frame payload for tactical testing / zero-mic desktop
    final chunkPayload = 'PCM16_SAMPLES_${_currentTxSequence}_CH${_activeChannel.id}';
    _currentTxChunks.add(chunkPayload);

    _bridge?.sendPttChunk(
      sessionId: _currentTxSessionId ?? 'session',
      sequence: _currentTxSequence,
      channel: _activeChannel.id,
      audioBase64: chunkPayload,
      isFinal: isFinal,
      priority: _activeChannel.isEmergency ? 'emergency' : 'normal',
    );
  }

  // --- INCOMING MESH EVENTS ---
  void handleIncomingFloorEvent(PttFloorEvent event) {
    if (event.channel.toUpperCase() != _activeChannel.id.toUpperCase()) {
      return;
    }

    if (event.isTransmitting) {
      // If we are currently transmitting and this is not emergency override, ignore
      if (_state == PttState.transmitting && event.priority != 'emergency') {
        return;
      }

      if (_state == PttState.transmitting && event.priority == 'emergency') {
        // Yield floor to emergency broadcast
        releasePtt();
      }

      _state = PttState.receiving;
      _activeSpeakerNickname = event.speakerNickname;
      _activeSpeakerCallsign = event.speakerCallsign;
      _activeSpeakerHash = event.speakerHash;

      // Start RX watchdog timer (resets floor if remote disappears without releasing)
      _rxWatchdogTimer?.cancel();
      _rxWatchdogTimer = Timer(const Duration(seconds: 12), () {
        if (_state == PttState.receiving) {
          _resetRxState();
        }
      });

      _startVuAnimation(transmitting: false);
      notifyListeners();
    } else {
      // Remote speaker released floor
      if (_state == PttState.receiving || _state == PttState.busy) {
        _resetRxState();
        if (_rogerBeepEnabled) {
          _triggerRogerBeep();
        }
      }
    }
  }

  void handleIncomingVoiceChunk(PttVoiceChunk chunk) {
    if (chunk.channel.toUpperCase() != _activeChannel.id.toUpperCase()) {
      return;
    }

    // Reset watchdog on each chunk
    _rxWatchdogTimer?.cancel();
    _rxWatchdogTimer = Timer(const Duration(seconds: 8), () {
      if (_state == PttState.receiving) {
        _resetRxState();
      }
    });

    if (_state != PttState.transmitting) {
      _state = PttState.receiving;
      _activeSpeakerNickname = chunk.senderNickname;
      _activeSpeakerCallsign = chunk.senderCallsign;
      _activeSpeakerHash = chunk.senderHash;
      _activeSpeakerSessionId = chunk.sessionId;
      _startVuAnimation(transmitting: false);
    }

    if (chunk.isFinal) {
      // Remote transmission concluded
      final log = PttTransmissionLog(
        id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: chunk.sessionId,
        channel: chunk.channel,
        senderHash: chunk.senderHash,
        senderNickname: chunk.senderNickname,
        senderCallsign: chunk.senderCallsign,
        durationSec: (chunk.sequence * 0.25).ceil(),
        chunkCount: chunk.sequence,
        priority: chunk.priority,
        timestampSec: chunk.timestampSec > 0 ? chunk.timestampSec : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _transmissionLogs.insert(0, log);
      if (_transmissionLogs.length > 50) {
        _transmissionLogs.removeLast();
      }

      _resetRxState();
      if (_rogerBeepEnabled) {
        _triggerRogerBeep();
      }
    }

    notifyListeners();
  }

  void _resetRxState() {
    _rxWatchdogTimer?.cancel();
    _stopVuAnimation();
    _state = PttState.idle;
    _activeSpeakerNickname = null;
    _activeSpeakerCallsign = null;
    _activeSpeakerHash = null;
    _activeSpeakerSessionId = null;
    _vuMeterLevel = 0.0;
    notifyListeners();
  }

  // --- VU METER & AUDIO ANIMATION ---
  void _startVuAnimation({required bool transmitting}) {
    _vuAnimationTimer?.cancel();
    final random = Random();
    _vuAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Dynamic realistic speech wave envelope
      final base = transmitting ? 0.65 : 0.55;
      final jitter = (random.nextDouble() * 0.35) - 0.15;
      _vuMeterLevel = (base + jitter).clamp(0.05, 1.0);
      notifyListeners();
    });
  }

  void _stopVuAnimation() {
    _vuAnimationTimer?.cancel();
    _vuMeterLevel = 0.0;
  }

  void _triggerRogerBeep() {
    _recentRogerBeep = true;
    notifyListeners();
    _rogerBeepTimer?.cancel();
    _rogerBeepTimer = Timer(const Duration(milliseconds: 600), () {
      _recentRogerBeep = false;
      notifyListeners();
    });
  }

  // --- SIMULATION FOR DEMO & TESTING ---
  void simulateRemoteTransmission({
    required String nickname,
    required String callsign,
    String? channelId,
    int durationSeconds = 3,
    bool isEmergency = false,
  }) {
    final targetChannel = channelId != null
        ? _availableChannels.firstWhere((c) => c.id == channelId, orElse: () => _activeChannel)
        : _activeChannel;

    if (targetChannel.id != _activeChannel.id) {
      selectChannel(targetChannel);
    }

    final sessionId = 'sim_${DateTime.now().millisecondsSinceEpoch}';
    final prio = isEmergency ? 'emergency' : 'normal';

    handleIncomingFloorEvent(PttFloorEvent(
      channel: targetChannel.id,
      speakerHash: 'sim_hash_${nickname.toLowerCase()}',
      speakerNickname: nickname,
      speakerCallsign: callsign,
      isTransmitting: true,
      priority: prio,
      timestampSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));

    int chunkIndex = 0;
    final totalChunks = durationSeconds * 4;
    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      chunkIndex++;
      final isFinal = chunkIndex >= totalChunks;
      handleIncomingVoiceChunk(PttVoiceChunk(
        sessionId: sessionId,
        sequence: chunkIndex,
        channel: targetChannel.id,
        senderHash: 'sim_hash_${nickname.toLowerCase()}',
        senderNickname: nickname,
        senderCallsign: callsign,
        audioBase64: 'SIMULATED_AUDIO_PCM_$chunkIndex',
        isFinal: isFinal,
        priority: prio,
        timestampSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));

      if (isFinal) {
        timer.cancel();
      }
    });
  }

  // --- CONTROLS ---
  void toggleVox(bool value) {
    _voxEnabled = value;
    notifyListeners();
  }

  void setSquelch(double value) {
    _squelchLevel = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleRogerBeep(bool value) {
    _rogerBeepEnabled = value;
    notifyListeners();
  }

  void clearLogs() {
    _transmissionLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _txTimer?.cancel();
    _txChunkTimer?.cancel();
    _rxWatchdogTimer?.cancel();
    _vuAnimationTimer?.cancel();
    _rogerBeepTimer?.cancel();
    super.dispose();
  }
}
