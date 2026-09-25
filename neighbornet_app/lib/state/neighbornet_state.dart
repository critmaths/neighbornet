import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/neighbornet_models.dart';
import '../services/neighbornet_bridge.dart';
import '../services/notification_service.dart';
import '../services/ptt_service.dart';
import '../services/voice_chat_service.dart';

class NeighborNetState extends ChangeNotifier {
  final NeighborNetBridge _bridge = NeighborNetBridge();
  late final PttService _pttService = PttService(bridge: _bridge);
  Timer? _pollTimer;
  VoiceChatService? _voiceChatService;

  bool _isInitialized = false;
  bool _isFirstRefresh = true;
  final Set<String> _seenMessageIds = {};
  final Set<String> _seenBulletinIds = {};
  final Map<String, int> _unreadCounts = {};

  AppThemeProfile _themeProfile = AppThemeProfile.defaultDark;

  NodeStatus? _status;
  List<PeerInfo> _peers = [];
  List<BulletinPost> _bulletins = [];
  List<SharedFileInfo> _sharedFiles = [];
  List<RoomInfo> _rooms = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};
  final Map<String, List<StewardVoteInfo>> _roomProposals = {};
  final Map<String, List<GovernanceEventInfo>> _roomAuditLogs = {};
  List<FormSchema> _formSchemas = [];
  final Map<String, List<FormEntry>> _formEntries = {};
  UserProfile? _myProfile;
  final Map<String, UserProfile> _peerProfiles = {};
  List<TacticalMarker> _markers = [];
  List<TracerouteSession> _traceroutes = [];
  TracerouteSession? _selectedTrace;
  bool _isTracing = false;

  String _currentChannel = 'general';
  String? _errorMessage;

  List<SerialDeviceInfo> _serialPorts = [];
  LoraRadioStatus? _loraStatus;
  bool _isLoraScanning = false;

  bool get isInitialized => _isInitialized;
  AppThemeProfile get themeProfile => _themeProfile;
  NodeStatus? get status => _status;
  List<PeerInfo> get peers => _peers;
  List<BulletinPost> get bulletins => _bulletins;
  List<SharedFileInfo> get sharedFiles => _sharedFiles;
  List<RoomInfo> get rooms => _rooms;
  List<FormSchema> get formSchemas => _formSchemas;
  UserProfile? get myProfile => _myProfile;
  Map<String, UserProfile> get peerProfiles => _peerProfiles;
  List<TacticalMarker> get markers => _markers;
  List<TracerouteSession> get traceroutes => _traceroutes;
  TracerouteSession? get selectedTrace => _selectedTrace;
  bool get isTracing => _isTracing;
  String get currentChannel => _currentChannel;
  String? get errorMessage => _errorMessage;

  List<SerialDeviceInfo> get serialPorts => _serialPorts;
  LoraRadioStatus? get loraStatus => _loraStatus;
  bool get isLoraScanning => _isLoraScanning;
  PttService get pttService => _pttService;


  List<ChatMessage> get currentMessages => getDisplayMessages(_currentChannel);
  int get nearbyCount => _peers.length;

  List<StewardVoteInfo> getProposals(String roomId) => _roomProposals[roomId] ?? _bridge.getProposals(roomId);
  List<GovernanceEventInfo> getAuditLog(String roomId) => _roomAuditLogs[roomId] ?? _bridge.getAuditLog(roomId);
  List<FormEntry> getFormEntriesForSchema(String schemaId) => _formEntries[schemaId] ?? _bridge.getFormEntries(schemaId);

  int getUnreadCount(String channel) => _unreadCounts[channel] ?? 0;
  int get totalUnreadCount => _unreadCounts.values.fold(0, (a, b) => a + b);

  void attachVoiceChatService(VoiceChatService service) {
    _voiceChatService = service;
    _voiceChatService?.setSignalSender((targetPeerId, type, data) {
      _sendSignalEnvelope(targetPeerId, type, data);
    });
  }

  List<ChatMessage> getDisplayMessages(String channel) {
    final raw = _channelMessages[channel] ?? [];
    return raw.where((m) => !m.content.startsWith('[SIGNAL:')).toList();
  }

  bool isDirectMessageChannel(String channel) => channel.startsWith('dm_');

  PeerInfo? getPeerForChannel(String channel) {
    if (!isDirectMessageChannel(channel)) return null;
    final hash = channel.substring('dm_'.length);
    try {
      return _peers.firstWhere((p) => p.destHash == hash);
    } catch (_) {
      return null;
    }
  }

  void selectDirectMessage(PeerInfo peer) {
    selectChannel('dm_${peer.destHash}');
  }

  Future<void> initialize({int port = 42424, bool isTransport = false}) async {
    try {
      await loadThemeProfile();
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

  Future<void> loadThemeProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt('tactical_theme_profile') ?? 0;
      if (index >= 0 && index < AppThemeProfile.values.length) {
        _themeProfile = AppThemeProfile.values[index];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeProfile(AppThemeProfile profile) async {
    _themeProfile = profile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tactical_theme_profile', profile.index);
    } catch (_) {}
  }

  ThemeData get themeData {
    switch (_themeProfile) {
      case AppThemeProfile.nightVisionRed:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF030000),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF1744),
            onPrimary: Colors.black,
            secondary: Color(0xFFFF5252),
            onSecondary: Colors.black,
            surface: Color(0xFF100002),
            onSurface: Color(0xFFFF8A80),
            error: Color(0xFFFF1744),
            onError: Colors.black,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF100002),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0x66FF1744), width: 1),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF080001),
            foregroundColor: Color(0xFFFF5252),
          ),
          navigationRailTheme: const NavigationRailThemeData(
            backgroundColor: Color(0xFF080001),
            selectedIconTheme: IconThemeData(color: Color(0xFFFF1744)),
            unselectedIconTheme: IconThemeData(color: Color(0x99FF5252)),
            selectedLabelTextStyle: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: Color(0x99FF5252)),
          ),
        );

      case AppThemeProfile.sunlightHighContrast:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF000000),
            onPrimary: Colors.white,
            secondary: Color(0xFFEAB308),
            onSecondary: Colors.black,
            surface: Color(0xFFF4F4F5),
            onSurface: Color(0xFF000000),
            error: Color(0xFFDC2626),
            onError: Colors.white,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFF4F4F5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF000000), width: 1.5),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF000000),
            foregroundColor: Color(0xFFFFFFFF),
          ),
          navigationRailTheme: const NavigationRailThemeData(
            backgroundColor: Color(0xFFE4E4E7),
            selectedIconTheme: IconThemeData(color: Color(0xFF000000)),
            unselectedIconTheme: IconThemeData(color: Color(0xFF71717A)),
            selectedLabelTextStyle: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: Color(0xFF71717A)),
          ),
        );

      case AppThemeProfile.defaultDark:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B0F19),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF59E0B),
            secondary: Color(0xFF06B6D4),
            surface: Color(0xFF131B2E),
            onSurface: Color(0xFFF1F5F9),
            error: Color(0xFFEF4444),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF131B2E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Color(0xFFF1F5F9),
          ),
        );
    }
  }

  Future<bool> executePanicWipe() async {
    final success = _bridge.panicWipe();
    if (success) {
      _seenMessageIds.clear();
      _seenBulletinIds.clear();
      _unreadCounts.clear();
      _channelMessages.clear();
      _roomProposals.clear();
      _roomAuditLogs.clear();
      _formSchemas.clear();
      _formEntries.clear();
      _peerProfiles.clear();
      _markers.clear();
      _traceroutes.clear();
      _selectedTrace = null;
      _myProfile = null;
      _currentChannel = 'general';
      _refreshState();
      notifyListeners();
    }
    return success;
  }

  void _refreshState() {
    if (!_bridge.isReady) return;

    _status = _bridge.getStatus();
    _peers = _bridge.getPeers();
    _bulletins = _bridge.getBulletins();
    _sharedFiles = _bridge.getSharedFiles();
    _rooms = _bridge.getRooms();
    _markers = _bridge.getMarkers();
    _traceroutes = _bridge.getTraceroutes();
    if (_selectedTrace != null) {
      final updated = _traceroutes.where((t) => t.traceId == _selectedTrace!.traceId).firstOrNull;
      if (updated != null) {
        _selectedTrace = updated;
      }
    }
    _formSchemas = _bridge.getFormSchemas();
    for (final s in _formSchemas) {
      _formEntries[s.id] = _bridge.getFormEntries(s.id);
    }
    final myP = _bridge.getMyProfile();
    if (myP != null) {
      _myProfile = myP;
    }
    final allP = _bridge.getAllProfiles();
    for (final p in allP) {
      if (p.destHash != _status?.destHash) {
        _peerProfiles[p.destHash] = p;
      }
    }
    final lora = _bridge.getLoraStatus();
    if (lora != null) {
      _loraStatus = lora;
    }


    // Check for new bulletins
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

    // Scan all known channels + DM channels for new messages & signals
    final allChannels = <String>{
      'general',
      'emergency',
      'barter',
      'skills',
      'logistics',
      'watercooler',
      ..._rooms.map((r) => r.id),
      ..._peers.map((p) => 'dm_${p.destHash}'),
    };

    final currentMsgs = _bridge.getChatHistory(_currentChannel);
    _channelMessages[_currentChannel] = currentMsgs;

    for (final ch in allChannels) {
      final history = (ch == _currentChannel) ? currentMsgs : _bridge.getChatHistory(ch);
      if (ch != _currentChannel) {
        _channelMessages[ch] = history;
      }

      for (final msg in history) {
        if (!_seenMessageIds.contains(msg.id)) {
          _seenMessageIds.add(msg.id);

          // Check if message is a WebRTC signal envelope
          if (msg.content.startsWith('[SIGNAL:')) {
            _handleSignalMessage(msg);
            continue;
          }

          if (!_isFirstRefresh && _status?.destHash != null && msg.senderHash != _status!.destHash) {
            if (ch != _currentChannel) {
              _unreadCounts[ch] = (_unreadCounts[ch] ?? 0) + 1;
            }

            final displayCh = isDirectMessageChannel(ch)
                ? 'DM from ${msg.senderNickname}'
                : msg.channel;

            NotificationService.instance.showMessageNotification(
              senderNickname: msg.senderNickname,
              channel: displayCh,
              content: msg.content,
            );
          }
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

  void _handleSignalMessage(ChatMessage msg) {
    try {
      // Format: [SIGNAL:targetHash:type:jsonPayload]
      final raw = msg.content.substring('[SIGNAL:'.length);
      final firstColon = raw.indexOf(':');
      if (firstColon == -1) return;
      final targetHash = raw.substring(0, firstColon);

      final rest = raw.substring(firstColon + 1);
      final secondColon = rest.indexOf(':');
      if (secondColon == -1) return;
      final type = rest.substring(0, secondColon);
      final payloadJson = rest.substring(secondColon + 1);

      // Verify destination is our node
      if (_status?.destHash != null && targetHash != _status!.destHash) {
        return;
      }

      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      if (type == 'offer') {
        _voiceChatService?.handleIncomingOffer(
          callerId: msg.senderHash,
          callerNickname: payload['callerNickname'] as String? ?? msg.senderNickname,
          sdpOffer: payload['sdp'] as String? ?? '',
          withVideo: payload['withVideo'] as bool? ?? false,
        );
        NotificationService.instance.showMessageNotification(
          senderNickname: msg.senderNickname,
          channel: 'Incoming Call',
          content: 'Incoming ${payload['withVideo'] == true ? 'Video' : 'Voice'} Call...',
        );
      } else if (type == 'answer') {
        _voiceChatService?.handleIncomingAnswer(payload['sdp'] as String? ?? '');
      } else if (type == 'candidate') {
        _voiceChatService?.handleIncomingCandidate(payload);
      } else if (type == 'hangup' || type == 'busy') {
        _voiceChatService?.handleHangup();
      }
    } catch (e) {
      debugPrint('[NeighborNetState] Error parsing signal envelope: $e');
    }
  }

  void _sendSignalEnvelope(String targetPeerId, String type, Map<String, dynamic> data) {
    final payload = jsonEncode(data);
    final envelope = '[SIGNAL:$targetPeerId:$type:$payload]';
    // Send envelope over general channel or peer DM
    _bridge.sendChat('general', envelope);
  }

  void startCallWithPeer(PeerInfo peer, {bool withVideo = false}) {
    _voiceChatService?.startCall(
      peer.destHash,
      peerNickname: peer.nickname,
      withVideo: withVideo,
    );
  }

  void selectChannel(String channel) {
    if (_currentChannel != channel) {
      _currentChannel = channel;
      _unreadCounts[channel] = 0;
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

  bool sendVoiceMemo({
    required String channel,
    required String base64Audio,
    required int durationSec,
    String content = 'Voice memo',
  }) {
    final success = _bridge.sendVoiceChat(
      channel: channel,
      content: content,
      audioBase64: base64Audio,
      audioDurationSec: durationSec,
    );
    if (success) {
      _channelMessages[channel] = _bridge.getChatHistory(channel);
      notifyListeners();
    }
    return success;
  }

  TacticalMarker? upsertMarker(TacticalMarker marker) {
    final saved = _bridge.upsertMarker(marker);
    if (saved != null) {
      _markers = _bridge.getMarkers();
      notifyListeners();
    }
    return saved;
  }

  bool deleteMarker(String markerId) {
    final success = _bridge.deleteMarker(markerId);
    if (success) {
      _markers = _bridge.getMarkers();
      notifyListeners();
    }
    return success;
  }

  void refreshMarkers() {
    _markers = _bridge.getMarkers();
    notifyListeners();
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

  String? publishFileExtended({
    required String path,
    required String description,
    String category = 'documents',
    String groupTag = 'Public Vault',
    String? passphrase,
  }) {
    final hash = _bridge.publishFileExtended(
      filePath: path,
      description: description,
      category: category,
      groupTag: groupTag,
      passphrase: passphrase,
    );
    if (hash != null) {
      _sharedFiles = _bridge.getSharedFiles();
      notifyListeners();
    }
    return hash;
  }

  bool requestFileDownload(String fileHash) {
    final success = _bridge.requestFile(fileHash);
    if (success) {
      _sharedFiles = _bridge.getSharedFiles();
      notifyListeners();
    }
    return success;
  }

  FileChunkProgress? getFileChunkStatus(String fileHash) {
    return _bridge.getFileChunkStatus(fileHash);
  }

  bool deleteSharedFile(String fileHash) {
    final ok = _bridge.deleteFile(fileHash);
    if (ok) {
      _sharedFiles = _bridge.getSharedFiles();
      notifyListeners();
    }
    return ok;
  }

  bool exportSharedFile({
    required String fileHash,
    required String targetPath,
    String? passphrase,
  }) {
    return _bridge.exportFile(
      fileHash: fileHash,
      targetPath: targetPath,
      passphrase: passphrase,
    );
  }

  void refreshSharedFiles() {
    _sharedFiles = _bridge.getSharedFiles();
    notifyListeners();
  }

  String? getCompletedFilePath(String fileHash) {
    return _bridge.getCompletedFilePath(fileHash);
  }

  RoomInfo? createRoom(String name, [String description = '', bool isPrivate = false]) {
    final meta = _bridge.createRoom(name, description, isPrivate: isPrivate);
    if (meta != null) {
      _rooms = _bridge.getRooms();
      selectChannel(meta.id);
      return meta;
    }
    return null;
  }

  bool proposeStewardVote({
    required String roomId,
    required String targetHash,
    required String targetNickname,
    required String action,
    required String reasonCategory,
    required String reasonDetails,
  }) {
    final id = _bridge.proposeStewardVote(
      roomId: roomId,
      targetHash: targetHash,
      targetNickname: targetNickname,
      action: action,
      reasonCategory: reasonCategory,
      reasonDetails: reasonDetails,
    );
    if (id != null) {
      _roomProposals[roomId] = _bridge.getProposals(roomId);
      notifyListeners();
      return true;
    }
    return false;
  }

  bool castVote(String proposalId, bool approve) {
    final success = _bridge.castVote(proposalId, approve);
    if (success && _currentChannel.startsWith('room_')) {
      _roomProposals[_currentChannel] = _bridge.getProposals(_currentChannel);
      _roomAuditLogs[_currentChannel] = _bridge.getAuditLog(_currentChannel);
      notifyListeners();
    }
    return success;
  }

  void refreshGovernance(String roomId) {
    if (_bridge.isReady) {
      _roomProposals[roomId] = _bridge.getProposals(roomId);
      _roomAuditLogs[roomId] = _bridge.getAuditLog(roomId);
      notifyListeners();
    }
  }

  String? exportIdentityMnemonic() {
    return _bridge.exportIdentityMnemonic();
  }

  String? restoreIdentity(String phraseOrHex) {
    final res = _bridge.restoreIdentity(phraseOrHex);
    if (res != null) {
      _refreshState();
      notifyListeners();
    }
    return res;
  }

  Future<void> refreshSerialPorts() async {
    _isLoraScanning = true;
    notifyListeners();
    try {
      _serialPorts = _bridge.listSerialPorts();
    } catch (_) {}
    _isLoraScanning = false;
    notifyListeners();
  }

  Future<bool> connectLoraRadio({
    required String portName,
    int baudRate = 115200,
    int freqHz = 915000000,
    int bwHz = 125000,
    int sf = 10,
    int cr = 5,
  }) async {
    final ok = _bridge.connectLora(
      portName: portName,
      baudRate: baudRate,
      freqHz: freqHz,
      bwHz: bwHz,
      sf: sf,
      cr: cr,
    );
    if (ok) {
      _loraStatus = _bridge.getLoraStatus();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> disconnectLoraRadio() async {
    final ok = _bridge.disconnectLora();
    _loraStatus = _bridge.getLoraStatus();
    notifyListeners();
    return ok;
  }

  Future<void> refreshFormSchemas() async {
    _formSchemas = _bridge.getFormSchemas();
    for (final s in _formSchemas) {
      _formEntries[s.id] = _bridge.getFormEntries(s.id);
    }
    notifyListeners();
  }

  Future<void> refreshFormEntries(String schemaId) async {
    _formEntries[schemaId] = _bridge.getFormEntries(schemaId);
    notifyListeners();
  }

  Future<FormSchema?> createFormSchema({
    required String title,
    required String description,
    required String category,
    required List<FormFieldDef> fields,
  }) async {
    final schema = _bridge.createFormSchema(
      title: title,
      description: description,
      category: category,
      fields: fields,
    );
    if (schema != null) {
      await refreshFormSchemas();
    }
    return schema;
  }

  Future<FormEntry?> submitFormEntry(String schemaId, Map<String, dynamic> data) async {
    final entry = _bridge.submitFormEntry(schemaId, data);
    if (entry != null) {
      await refreshFormEntries(schemaId);
    }
    return entry;
  }

  UserProfile? getProfileForPeer(String destHash) {
    if (_myProfile != null && _myProfile!.destHash == destHash) {
      return _myProfile;
    }
    return _peerProfiles[destHash] ?? _bridge.getPeerProfile(destHash);
  }

  Future<void> refreshMyProfile() async {
    final prof = _bridge.getMyProfile();
    if (prof != null) {
      _myProfile = prof;
      notifyListeners();
    }
  }

  Future<void> refreshPeerProfiles() async {
    final list = _bridge.getAllProfiles();
    for (final p in list) {
      if (p.destHash == _status?.destHash) {
        _myProfile = p;
      } else {
        _peerProfiles[p.destHash] = p;
      }
    }
    notifyListeners();
  }

  bool updateMyProfile(UserProfile profile) {
    final updated = _bridge.updateMyProfile(profile);
    if (updated != null) {
      _myProfile = updated;
      _status = _bridge.getStatus();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Imports an optical QR or air-gapped peer profile, storing it in memory and address book.
  bool importPeerContact(UserProfile profile) {
    if (profile.destHash.isEmpty) return false;
    _peerProfiles[profile.destHash] = profile;
    final existingPeer = _peers.any((p) => p.destHash == profile.destHash);
    if (!existingPeer) {
      _peers.add(PeerInfo(
        destHash: profile.destHash,
        nickname: profile.nickname.isNotEmpty ? profile.nickname : 'Neighbor',
        addr: 'optical/air-gap',
        isTransport: false,
        lastSeenEpochSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));
    }
    notifyListeners();
    return true;
  }

  // --- TRACEROUTE & MESH ROUTE DISCOVERY ---

  void selectTrace(TracerouteSession? trace) {
    _selectedTrace = trace;
    notifyListeners();
  }

  Future<TracerouteSession?> initiateTraceroute(String targetHash, {int maxTtl = 8}) async {
    _isTracing = true;
    notifyListeners();
    try {
      final trace = _bridge.initiateTraceroute(targetHash, maxTtl: maxTtl);
      if (trace != null) {
        _traceroutes = _bridge.getTraceroutes();
        _selectedTrace = trace;
      }
      return trace;
    } finally {
      _isTracing = false;
      notifyListeners();
    }
  }

  Future<TracerouteSession?> simulateTrace(String targetHash) async {
    _isTracing = true;
    notifyListeners();
    try {
      final trace = _bridge.simulateTrace(targetHash);
      if (trace != null) {
        _traceroutes = _bridge.getTraceroutes();
        _selectedTrace = trace;
      }
      return trace;
    } finally {
      _isTracing = false;
      notifyListeners();
    }
  }

  void refreshTraceroutes() {
    _traceroutes = _bridge.getTraceroutes();
    if (_selectedTrace != null) {
      final updated = _traceroutes.where((t) => t.traceId == _selectedTrace!.traceId).firstOrNull;
      if (updated != null) {
        _selectedTrace = updated;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pttService.dispose();
    _bridge.stopNode();
    super.dispose();
  }
}

