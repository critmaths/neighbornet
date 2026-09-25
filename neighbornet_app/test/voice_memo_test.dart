import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/voice_memo_service.dart';

void main() {
  group('Voice Memo Service & Chat Voice Integration Tests', () {
    test('ChatMessage voice memo flag and duration attributes', () {
      final textMsg = ChatMessage(
        id: 'msg-1',
        channel: 'general',
        senderHash: 'hash-1',
        senderNickname: 'Alice',
        content: 'Regular text message',
        timestampSec: 1700000000,
      );
      expect(textMsg.isVoiceMemo, false);

      final voiceMsg = ChatMessage(
        id: 'msg-2',
        channel: 'emergency',
        senderHash: 'hash-2',
        senderNickname: 'Bob',
        content: '🎙️ Voice Memo (5s)',
        timestampSec: 1700000000,
        audioBase64: 'UklGRi4AAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=',
        audioDurationSec: 5,
      );
      expect(voiceMsg.isVoiceMemo, true);
      expect(voiceMsg.audioDurationSec, 5);

      final json = voiceMsg.toJson();
      expect(json['audio_base64'], isNotNull);
      expect(json['audio_duration_sec'], 5);

      final restored = ChatMessage.fromJson(json);
      expect(restored.isVoiceMemo, true);
      expect(restored.audioDurationSec, 5);
      expect(restored.audioBase64, voiceMsg.audioBase64);
    });

    test('VoiceMemoService recording state machine and waveform', () async {
      final service = VoiceMemoService();
      expect(service.isRecording, false);

      service.startRecording();
      expect(service.isRecording, true);

      // Wait 250ms for timer ticks and waveform collection
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(service.liveWaveform.isNotEmpty, true);

      final result = await service.stopRecording();
      expect(service.isRecording, false);
      expect(result, isNotNull);
      expect(result!.base64Audio.isNotEmpty, true);
      expect(result.durationSec >= 1, true);
    });

    test('VoiceMemoService playback progress and stop', () async {
      final service = VoiceMemoService();
      expect(service.playingMessageId, isNull);

      service.playMemo('msg-audio-99', 'fake-b64-payload', 1);
      expect(service.isPlaying('msg-audio-99'), true);
      expect(service.playingMessageId, 'msg-audio-99');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(service.playbackProgress > 0.0, true);

      service.stopPlayback();
      expect(service.playingMessageId, isNull);
      expect(service.playbackProgress, 0.0);
    });
  });
}
