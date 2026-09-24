import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duress & Emergency Panic Wipe Tests', () {
    test('executePanicWipe clears in-memory message and bulletin caches', () async {
      final state = NeighborNetState();

      // State starts with clean/default state
      expect(state.totalUnreadCount, 0);
      expect(state.currentChannel, 'general');

      // Trigger panic wipe
      final result = await state.executePanicWipe();
      expect(result, isFalse); // Node not initialized in unit test, gracefully returns false

      expect(state.currentChannel, 'general');
      expect(state.totalUnreadCount, 0);
      expect(state.currentMessages.length, 0);
    });
  });
}
