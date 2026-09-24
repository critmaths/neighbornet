import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tactical Visual Profiles & Theme Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default theme profile is defaultDark with amber primary', () {
      final state = NeighborNetState();
      expect(state.themeProfile, AppThemeProfile.defaultDark);

      final theme = state.themeData;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0F19));
      expect(theme.colorScheme.primary, const Color(0xFFF59E0B));
    });

    test('Night Vision Red profile configures pure OLED dark adaptation colors', () async {
      final state = NeighborNetState();
      await state.setThemeProfile(AppThemeProfile.nightVisionRed);

      expect(state.themeProfile, AppThemeProfile.nightVisionRed);
      final theme = state.themeData;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF030000));
      expect(theme.colorScheme.primary, const Color(0xFFFF1744));
    });

    test('Sunlight High-Contrast profile configures high-visibility daylight palette', () async {
      final state = NeighborNetState();
      await state.setThemeProfile(AppThemeProfile.sunlightHighContrast);

      expect(state.themeProfile, AppThemeProfile.sunlightHighContrast);
      final theme = state.themeData;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.primary, const Color(0xFF000000));
    });

    test('Theme profile persists to SharedPreferences and loads on startup', () async {
      SharedPreferences.setMockInitialValues({'tactical_theme_profile': 1}); // nightVisionRed

      final state = NeighborNetState();
      await state.loadThemeProfile();

      expect(state.themeProfile, AppThemeProfile.nightVisionRed);
    });
  });
}
