import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/neighbornet_models.dart';
import '../services/neighbornet_bridge.dart';

class NeighborNetState extends ChangeNotifier {
  final NeighborNetBridge _bridge = NeighborNetBridge();
  Timer? _pollTimer;

  bool _isInitialized = false;
  NodeStatus? _status;
  List<PeerInfo> _peers = [];
  List<BulletinPost> _bulletins = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};

  String _currentChannel = 'general';
  String? _errorMessage;

  bool get isInitialized => _isInitialized;
  NodeStatus? get status => _status;
  List<PeerInfo> get peers => _peers;
  List<BulletinPost> get bulletins => _bulletins;
  String get currentChannel => _currentChannel;
  String? get errorMessage => _errorMessage;

  List<ChatMessage> get currentMessages => _channelMessages[_currentChannel] ?? [];

  int get nearbyCount => _peers.length;

  Future<void> initialize({int port = 42424, bool isTransport = false}) async {
    try {
      final appDir = Directory(
        '${Platform.environment['APPDATA'] ?? Directory.current.path}${Platform.pathSeparator}NeighborNet',
      );
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }

      final success = _bridge.initNode(
        dataDir: appDir.path,
        listenPort: port,
        isTransport: isTransport,
      );

      if (success) {
        _isInitialized = true;
        _refreshState();
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          _refreshState();
        });
      } else {
        _errorMessage = 'Failed to bind Reticulum network socket';
      }
    } catch (e) {
      _errorMessage = 'Initialization error: $e';
    }
    notifyListeners();
  }

  void _refreshState() {
    if (!_bridge.isReady) return;

    _status = _bridge.getStatus();
    _peers = _bridge.getPeers();
    _bulletins = _bridge.getBulletins();

    // Refresh active channel messages
    final msgs = _bridge.getChatHistory(_currentChannel);
    _channelMessages[_currentChannel] = msgs;

    notifyListeners();
  }

  void selectChannel(String channel) {
    if (_currentChannel != channel) {
      _currentChannel = channel;
      final msgs = _bridge.getChatHistory(channel);
      _channelMessages[channel] = msgs;
      notifyListeners();
    }
  }

  bool setNickname(String newName) {
    final success = _bridge.setNickname(newName);
    if (success) {
      _status = _bridge.getStatus();
      notifyListeners();
    }
    return success;
  }

  bool sendChatMessage(String content) {
    if (content.trim().isEmpty) return false;
    final success = _bridge.sendChat(_currentChannel, content.trim());
    if (success) {
      _channelMessages[_currentChannel] = _bridge.getChatHistory(_currentChannel);
      notifyListeners();
    }
    return success;
  }

  bool postBulletin({
    required String title,
    required String body,
    required String urgency,
  }) {
    final success = _bridge.postBulletin(title.trim(), body.trim(), urgency);
    if (success) {
      _bulletins = _bridge.getBulletins();
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bridge.stopNode();
    super.dispose();
  }
}
