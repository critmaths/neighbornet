import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/tray_and_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrayAndWindowService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default values follow requirements: taskbar+tray default, close to tray enabled', () async {
      final service = TrayAndWindowService.instance;
      await service.initialize();

      // Default is that it shows on the task bar AND in the system tray
      expect(service.minimizeToTrayOnly, isFalse);
      // Default is that closing sends to tray
      expect(service.closeToTray, isTrue);
    });

    test('Can toggle minimizeJustToTray preference', () async {
      final service = TrayAndWindowService.instance;
      await service.initialize();

      await service.setMinimizeToTrayOnly(true);
      expect(service.minimizeToTrayOnly, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('neighbornet_minimize_to_tray_only'), isTrue);

      await service.setMinimizeToTrayOnly(false);
      expect(service.minimizeToTrayOnly, isFalse);
      expect(prefs.getBool('neighbornet_minimize_to_tray_only'), isFalse);
    });

    test('Can toggle closeToTray preference', () async {
      final service = TrayAndWindowService.instance;
      await service.initialize();

      await service.setCloseToTray(false);
      expect(service.closeToTray, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('neighbornet_close_to_tray'), isFalse);

      await service.setCloseToTray(true);
      expect(service.closeToTray, isTrue);
      expect(prefs.getBool('neighbornet_close_to_tray'), isTrue);
    });
  });
}
