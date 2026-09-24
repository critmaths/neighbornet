// ignore_for_file: deprecated_member_use
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

class TrayAndWindowService extends ChangeNotifier with TrayListener, WindowListener {
  static final TrayAndWindowService instance = TrayAndWindowService._internal();

  TrayAndWindowService._internal();

  static const String _prefKeyMinimizeToTrayOnly = 'neighbornet_minimize_to_tray_only';
  static const String _prefKeyCloseToTray = 'neighbornet_close_to_tray';

  bool _isDesktop = false;
  bool _initialized = false;

  // Defaults:
  // - Default is that it shows on the task bar AND in the system tray (minimizeToTrayOnly = false)
  // - Default is to send to tray on X close (closeToTray = true)
  bool _minimizeToTrayOnly = false;
  bool _closeToTray = true;

  bool get isDesktop => _isDesktop;
  bool get minimizeToTrayOnly => _minimizeToTrayOnly;
  bool get closeToTray => _closeToTray;

  Future<void> initialize() async {
    if (_initialized) return;

    // Check if we are running on desktop and not in a headless test environment
    try {
      _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    } catch (_) {
      _isDesktop = false;
    }

    // Load persisted settings
    try {
      final prefs = await SharedPreferences.getInstance();
      _minimizeToTrayOnly = prefs.getBool(_prefKeyMinimizeToTrayOnly) ?? false;
      _closeToTray = prefs.getBool(_prefKeyCloseToTray) ?? true;
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error loading prefs: $e');
    }

    if (_isDesktop) {
      try {
        await windowManager.ensureInitialized();
        windowManager.addListener(this);
        await windowManager.setPreventClose(true);

        trayManager.addListener(this);
        await _setupTray();
      } catch (e) {
        debugPrint('[TrayAndWindowService] Desktop window/tray initialization error: $e');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _setupTray() async {
    if (!_isDesktop) return;

    try {
      final iconPath = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('NeighborNet - Community Mesh');

      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_app',
            label: 'Open NeighborNet',
            onClick: (_) => showWindow(),
          ),
          MenuItem(
            key: 'minimize_to_tray',
            label: 'Minimize to Tray',
            onClick: (_) => minimizeToTray(),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit NeighborNet',
            onClick: (_) => exitApp(),
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error setting up tray: $e');
    }
  }

  Future<void> setMinimizeToTrayOnly(bool value) async {
    _minimizeToTrayOnly = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyMinimizeToTrayOnly, value);
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error saving minimizeToTrayOnly: $e');
    }
  }

  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyCloseToTray, value);
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error saving closeToTray: $e');
    }
  }

  Future<void> showWindow() async {
    if (!_isDesktop) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error showing window: $e');
    }
  }

  Future<void> minimizeToTray() async {
    if (!_isDesktop) return;
    try {
      // Hiding removes it from the taskbar so it resides only in the system tray
      await windowManager.hide();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error hiding window to tray: $e');
    }
  }

  Future<void> exitApp() async {
    if (!_isDesktop) return;
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await trayManager.destroy();
      await windowManager.destroy();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error destroying window/tray: $e');
    }
  }

  // WindowListener Callbacks
  @override
  void onWindowClose() async {
    if (_closeToTray) {
      await minimizeToTray();
    } else {
      await exitApp();
    }
  }

  @override
  void onWindowMinimize() async {
    if (_minimizeToTrayOnly) {
      // If user enabled 'minimize just to tray', hide the window so it is not in the taskbar
      await windowManager.hide();
    }
    // If _minimizeToTrayOnly is false, the default Windows behavior keeps it on taskbar
    // while the tray icon also remains visible.
  }

  // TrayListener Callbacks
  @override
  void onTrayIconMouseDown() async {
    await showWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_app':
        await showWindow();
        break;
      case 'minimize_to_tray':
        await minimizeToTray();
        break;
      case 'exit_app':
        await exitApp();
        break;
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
