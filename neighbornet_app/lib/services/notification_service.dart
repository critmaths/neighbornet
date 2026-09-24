import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';
import 'tray_and_window_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  static const String _prefKeyNotificationsEnabled = 'neighbornet_notifications_enabled';

  bool _isWindows = false;
  bool _initialized = false;
  bool _enabled = true;
  WindowsNotification? _winNotify;

  bool get isWindows => _isWindows;
  bool get enabled => _enabled;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _isWindows = !kIsWeb && Platform.isWindows;
    } catch (_) {
      _isWindows = false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKeyNotificationsEnabled) ?? true;
    } catch (e) {
      debugPrint('[NotificationService] Error loading prefs: $e');
    }

    if (_isWindows) {
      try {
        _winNotify = WindowsNotification(
          applicationId: r"NeighborNet.Community.App",
        );
        await _winNotify?.initNotificationCallBack((details) {
          if (details.eventType == EventType.onActivate) {
            TrayAndWindowService.instance.showWindow();
          }
        });
      } catch (e) {
        debugPrint('[NotificationService] WindowsNotification init error: $e');
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
    if (!_enabled || !_isWindows || _winNotify == null) return;

    try {
      final messageNotification = NotificationMessage.fromPluginTemplate(
        "msg_${DateTime.now().millisecondsSinceEpoch}",
        '#$channel • $senderNickname',
        content,
      );

      await _winNotify?.showNotificationPluginTemplate(messageNotification);
    } catch (e) {
      debugPrint('[NotificationService] Error displaying message notification: $e');
    }
  }

  Future<void> showBulletinNotification({
    required String title,
    required String author,
    required String urgency,
  }) async {
    if (!_enabled || !_isWindows || _winNotify == null) return;

    try {
      final bulletinNotification = NotificationMessage.fromPluginTemplate(
        "bull_${DateTime.now().millisecondsSinceEpoch}",
        '[$urgency BULLETIN] $title',
        'Posted by $author to the community bulletin board.',
      );

      await _winNotify?.showNotificationPluginTemplate(bulletinNotification);
    } catch (e) {
      debugPrint('[NotificationService] Error displaying bulletin notification: $e');
    }
  }
}
