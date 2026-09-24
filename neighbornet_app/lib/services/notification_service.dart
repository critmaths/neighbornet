import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tray_and_window_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  static const String _prefKeyNotificationsEnabled = 'neighbornet_notifications_enabled';

  bool _isDesktop = false;
  bool _initialized = false;
  bool _enabled = true;

  bool get isDesktop => _isDesktop;
  bool get enabled => _enabled;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    } catch (_) {
      _isDesktop = false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKeyNotificationsEnabled) ?? true;
    } catch (e) {
      debugPrint('[NotificationService] Error loading prefs: $e');
    }

    if (_isDesktop) {
      try {
        await localNotifier.setup(
          appName: 'NeighborNet',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
      } catch (e) {
        debugPrint('[NotificationService] Error initializing localNotifier: $e');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyNotificationsEnabled, value);
    } catch (e) {
      debugPrint('[NotificationService] Error saving enabled state: $e');
    }
  }

  Future<void> showMessageNotification({
    required String senderNickname,
    required String channel,
    required String content,
  }) async {
    if (!_enabled || !_isDesktop) return;

    try {
      final notification = LocalNotification(
        title: '#$channel • $senderNickname',
        body: content,
        silent: false,
      );

      notification.onClick = () {
        TrayAndWindowService.instance.showWindow();
      };

      await notification.show();
    } catch (e) {
      debugPrint('[NotificationService] Error displaying message notification: $e');
    }
  }

  Future<void> showBulletinNotification({
    required String title,
    required String author,
    required String urgency,
  }) async {
    if (!_enabled || !_isDesktop) return;

    try {
      final notification = LocalNotification(
        title: '[$urgency BULLETIN] $title',
        body: 'Posted by $author to the community bulletin board.',
        silent: false,
      );

      notification.onClick = () {
        TrayAndWindowService.instance.showWindow();
      };

      await notification.show();
    } catch (e) {
      debugPrint('[NotificationService] Error displaying bulletin notification: $e');
    }
  }
}
