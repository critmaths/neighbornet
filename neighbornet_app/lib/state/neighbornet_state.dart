import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/neighbornet_models.dart';
import '../services/neighbornet_bridge.dart';
import '../services/notification_service.dart';

class NeighborNetState extends ChangeNotifier {
  final NeighborNetBridge _bridge = NeighborNetBridge();
  Timer? _pollTimer;

  bool _isInitialized = false;
  bool _isFirstRefresh = true;
  final Set<String> _seenMessageIds = {};
  final Set<String> _seenBulletinIds = {};

  NodeStatus? _status;
  List<PeerInfo> _peers = [];
  List<BulletinPost> _bulletins = [];
  List<SharedFileInfo> _sharedFiles = [];
  List<RoomInfo> _rooms = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};
  final Map<String, List<StewardVoteInfo>> _roomProposals = {};
  final Map<String, List<GovernanceEventInfo>> _roomAuditLogs = {};

  String _currentChannel = 'general';
  String? _errorMessage;

  bool get isInitialized => _isInitialized;
  NodeStatus? get status => _status;
  List<PeerInfo> get peers => _peers;
  List<BulletinPost> get bulletins => _bulletins;
  List<SharedFileInfo> get sharedFiles => _sharedFiles;
  List<RoomInfo> get rooms => _rooms;
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
    _sharedFiles = _bridge.getSharedFiles();
    _rooms = _bridge.getRooms();

    // Check for new bulletins to notify
    for (final b in _bulletins) {
      if (!_seenBulletinIds.contains(b.id)) {
        _seenBulletinIds.add(b.id);
        if (!_isFirstRefresh && _status?.destHash != null && b.authorHash != _status!.destHash) {
          NotificationService.instance.showBulletinNotification(
            title: b.title,
            author: b.authorNickname,
            urgency: b.urgency,
          );
        }
      }
    }

    // Refresh active channel messages
    final msgs = _bridge.getChatHistory(_currentChannel);
    _channelMessages[_currentChannel] = msgs;

    // Check for new chat messages to notify
    for (final msg in msgs) {
      if (!_seenMessageIds.contains(msg.id)) {
        _seenMessageIds.add(msg.id);
        if (!_isFirstRefresh && _status?.destHash != null && msg.senderHash != _status!.destHash) {
          NotificationService.instance.showMessageNotification(
            senderNickname: msg.senderNickname,
            channel: msg.channel,
            content: msg.content,
          );
        }
      }
    }

    // Refresh room governance data if in a custom room
    if (_currentChannel.startsWith('room_')) {
      _roomProposals[_currentChannel] = _bridge.getProposals(_currentChannel);
      _roomAuditLogs[_currentChannel] = _bridge.getAuditLog(_currentChannel);
    }

    _isFirstRefresh = false;
    notifyListeners();
  }

  void selectChannel(String channel) {
    if (_currentChannel != channel) {
      _currentChannel = channel;
      final msgs = _bridge.getChatHistory(channel);
      _channelMessages[channel] = msgs;
      if (channel.startsWith('room_')) {
        _roomProposals[channel] = _bridge.getProposals(channel);
        _roomAuditLogs[channel] = _bridge.getAuditLog(channel);
      }
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

  String? publishFile(String path, String description) {
    final hash = _bridge.publishFile(path, description);
    if (hash != null) {
      _sharedFiles = _bridge.getSharedFiles();
      notifyListeners();
    }
    return hash;
  }

  bool requestFile(String fileHash) {
    final success = _bridge.requestFile(fileHash);
    if (success) {
      _sharedFiles = _bridge.getSharedFiles();
      notifyListeners();
    }
    return success;
  }

  String? getCompletedFilePath(String fileHash) {
    return _bridge.getCompletedFilePath(fileHash);
  }

  RoomInfo? createRoom(String name, String description, {bool isPrivate = false}) {
    final room = _bridge.createRoom(name, description, isPrivate: isPrivate);
    if (room != null) {
      _rooms = _bridge.getRooms();
      selectChannel(room.id);
    }
    return room;
  }

  String? proposeStewardVote({
    required String roomId,
    required String targetHash,
    required String targetNickname,
    required String action,
    required String reasonCategory,
    required String reasonDetails,
  }) {
    final propId = _bridge.proposeStewardVote(
      roomId: roomId,
      targetHash: targetHash,
      targetNickname: targetNickname,
      action: action,
      reasonCategory: reasonCategory,
      reasonDetails: reasonDetails,
    );
    if (propId != null) {
      _roomProposals[roomId] = _bridge.getProposals(roomId);
      _roomAuditLogs[roomId] = _bridge.getAuditLog(roomId);
      notifyListeners();
    }
    return propId;
  }

  bool castVote(String proposalId, bool approve) {
    final success = _bridge.castVote(proposalId, approve);
    if (success) {
      _refreshState();
    }
    return success;
  }

  List<StewardVoteInfo> getProposals(String roomId) {
    return _roomProposals[roomId] ?? _bridge.getProposals(roomId);
  }

  List<GovernanceEventInfo> getAuditLog(String roomId) {
    return _roomAuditLogs[roomId] ?? _bridge.getAuditLog(roomId);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bridge.stopNode();
    super.dispose();
  }
}
