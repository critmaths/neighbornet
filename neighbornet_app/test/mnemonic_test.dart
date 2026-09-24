import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BIP-39 Mnemonic Paper Key & Identity Tests', () {
    test('exportIdentityMnemonic returns null gracefully when not initialized', () {
      final state = NeighborNetState();
      final phrase = state.exportIdentityMnemonic();
      expect(phrase, isNull);
    });

    test('restoreIdentity returns false gracefully on invalid seed phrase or uninitialized bridge', () async {
      final state = NeighborNetState();
      final result = await state.restoreIdentity('invalid phrase with random nonsense');
      expect(result, isFalse);
    });
  });
}
