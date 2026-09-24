import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BIP-39 Mnemonic Paper Key & Identity Tests', () {
    test('exportIdentityMnemonic returns null gracefully when not initialized', () {
      final bridge = NeighborNetBridge();
      expect(bridge.exportIdentityMnemonic(), isNull);
    });

    test('restoreIdentity returns false gracefully on invalid seed phrase or uninitialized bridge', () {
      final bridge = NeighborNetBridge();
      expect(bridge.restoreIdentity('invalid phrase'), isNull);
    });

    test('NeighborNetState delegates export and restore methods safely', () {
      final state = NeighborNetState();
      expect(state.exportIdentityMnemonic(), isNull);
      expect(state.restoreIdentity('invalid seed phrase'), isNull);
    });
  });
}
