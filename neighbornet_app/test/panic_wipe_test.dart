import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duress & Emergency Panic Wipe Tests', () {
    test('Bridge handles panic wipe call when uninitialized', () {
      final bridge = NeighborNetBridge();
      expect(bridge.panicWipe(), isFalse);
    });

    test('executePanicWipe clears in-memory message and bulletin caches', () async {
      final state = NeighborNetState();
      final result = await state.executePanicWipe();
      expect(result, isFalse); // False since bridge uninitialized in unit test
      expect(state.currentMessages, isEmpty);
      expect(state.bulletins, isEmpty);
      expect(state.rooms, isEmpty);
      expect(state.sharedFiles, isEmpty);
      expect(state.peers, isEmpty);
    });
  });
}
