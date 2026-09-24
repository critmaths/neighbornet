import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default values follow requirements: notifications enabled by default', () async {
      final service = NotificationService.instance;
      await service.initialize();

      expect(service.enabled, isTrue);
    });

    test('Can toggle notification enabled state and persist to SharedPreferences', () async {
      final service = NotificationService.instance;
      await service.initialize();

      await service.setEnabled(false);
      expect(service.enabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('neighbornet_notifications_enabled'), isFalse);

      await service.setEnabled(true);
      expect(service.enabled, isTrue);
      expect(prefs.getBool('neighbornet_notifications_enabled'), isTrue);
    });
  });
}
