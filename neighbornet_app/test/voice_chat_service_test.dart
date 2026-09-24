import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/voice_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceChatService Tests', () {
    test('Initial state is idle and video is disabled', () {
      final service = VoiceChatService();

      expect(service.state, equals(CallState.idle));
      expect(service.isMuted, isFalse);
      expect(service.isVideoEnabled, isFalse);
      expect(service.lastError, isEmpty);
    });

    test('Mute toggle flips isMuted state', () {
      final service = VoiceChatService();

      expect(service.isMuted, isFalse);
      service.toggleMute();
      expect(service.isMuted, isTrue);
      service.toggleMute();
      expect(service.isMuted, isFalse);
    });

    test('End call cleans up and sets state to idle', () {
      final service = VoiceChatService();
      service.endCall();

      expect(service.state, equals(CallState.idle));
      expect(service.isMuted, isFalse);
      expect(service.isVideoEnabled, isFalse);
    });
  });
}
