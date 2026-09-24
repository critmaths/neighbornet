import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../models/neighbornet_models.dart';

// Native function typedefs
typedef _NativeInit = Bool Function(Pointer<Utf8>, Uint16, Bool);
typedef _DartInit = bool Function(Pointer<Utf8>, int, bool);

typedef _NativeStop = Void Function();
typedef _DartStop = void Function();

typedef _NativeGetJson = Pointer<Utf8> Function();
typedef _DartGetJson = Pointer<Utf8> Function();

typedef _NativeSetNickname = Bool Function(Pointer<Utf8>);
typedef _DartSetNickname = bool Function(Pointer<Utf8>);

typedef _NativeSendChat = Bool Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DartSendChat = bool Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _NativeGetChatHistory = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartGetChatHistory = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _NativePostBulletin = Bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _DartPostBulletin = bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _NativeFreeString = Void Function(Pointer<Utf8>);
typedef _DartFreeString = void Function(Pointer<Utf8>);

typedef _NativePublishFile = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DartPublishFile = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _NativeRequestFile = Bool Function(Pointer<Utf8>);
typedef _DartRequestFile = bool Function(Pointer<Utf8>);

typedef _NativeGetFilePath = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartGetFilePath = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _NativeCreateRoom = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Bool);
typedef _DartCreateRoom = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, bool);

typedef _NativeProposeVote = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);
typedef _DartProposeVote = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);

typedef _NativeCastVote = Bool Function(Pointer<Utf8>, Bool);
typedef _DartCastVote = bool Function(Pointer<Utf8>, bool);

typedef _NativeGetRoomData = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartGetRoomData = Pointer<Utf8> Function(Pointer<Utf8>);

class NeighborNetBridge {
  static final NeighborNetBridge _instance = NeighborNetBridge._internal();
  factory NeighborNetBridge() => _instance;
  NeighborNetBridge._internal();

  DynamicLibrary? _dylib;
  bool _isInitialized = false;

  late _DartInit _init;
  late _DartStop _stop;
  late _DartGetJson _getStatusJson;
  late _DartSetNickname _setNickname;
  late _DartGetJson _getPeersJson;
  late _DartSendChat _sendChat;
  late _DartGetChatHistory _getChatHistoryJson;
  late _DartPostBulletin _postBulletin;
  late _DartGetJson _getBulletinsJson;
  late _DartFreeString _freeString;

  late _DartPublishFile _publishFile;
  late _DartGetJson _getSharedFilesJson;
  late _DartRequestFile _requestFile;
  late _DartGetFilePath _getFilePath;

  late _DartCreateRoom _createRoom;
  late _DartGetJson _getRoomsJson;
  late _DartProposeVote _proposeVote;
  late _DartCastVote _castVote;
  late _DartGetRoomData _getProposalsJson;
  late _DartGetRoomData _getAuditLogJson;

  bool get isReady => _isInitialized;

  void _loadLibrary() {
    if (_dylib != null) return;

    final cwd = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    final candidatePaths = <String>[
      if (Platform.environment.containsKey('NEIGHBORNET_CORE_LIB'))
        Platform.environment['NEIGHBORNET_CORE_LIB']!,
      '$exeDir${Platform.pathSeparator}neighbornet_core.dll',
      '$exeDir${Platform.pathSeparator}libneighbornet_core.so',
      '$exeDir${Platform.pathSeparator}libneighbornet_core.dylib',
      '$cwd/../neighbornet_core/target/release/neighbornet_core.dll',
      '$cwd/../neighbornet_core/target/release/libneighbornet_core.so',
      '$cwd/../neighbornet_core/target/release/libneighbornet_core.dylib',
      '$cwd/../neighbornet_core/target/debug/neighbornet_core.dll',
      '$cwd/../neighbornet_core/target/debug/libneighbornet_core.so',
      '$cwd/../neighbornet_core/target/debug/libneighbornet_core.dylib',
      '$cwd/neighbornet_core/target/release/neighbornet_core.dll',
      '$cwd/neighbornet_core/target/release/libneighbornet_core.so',
      '$cwd/neighbornet_core/target/release/libneighbornet_core.dylib',
      r'C:\Users\criti\RiderProjects\Neighbornet\neighbornet_core\target\release\neighbornet_core.dll',
      r'C:\Users\criti\RiderProjects\Neighbornet\neighbornet_core\target\debug\neighbornet_core.dll',
      'neighbornet_core.dll',
      'libneighbornet_core.dylib',
      'libneighbornet_core.so',
    ];

    for (final path in candidatePaths) {
      if (File(path).existsSync()) {
        try {
          _dylib = DynamicLibrary.open(path);
          break;
        } catch (_) {}
      }
    }

    _dylib ??= DynamicLibrary.open(
      Platform.isWindows
          ? 'neighbornet_core.dll'
          : Platform.isMacOS
              ? 'libneighbornet_core.dylib'
              : 'libneighbornet_core.so',
    );

    // Bind functions
    _init = _dylib!.lookupFunction<_NativeInit, _DartInit>('neighbornet_init');
    _stop = _dylib!.lookupFunction<_NativeStop, _DartStop>('neighbornet_stop_node');
    _getStatusJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_status_json');
    _setNickname = _dylib!.lookupFunction<_NativeSetNickname, _DartSetNickname>('neighbornet_set_nickname');
    _getPeersJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_peers_json');
    _sendChat = _dylib!.lookupFunction<_NativeSendChat, _DartSendChat>('neighbornet_send_chat');
    _getChatHistoryJson = _dylib!.lookupFunction<_NativeGetChatHistory, _DartGetChatHistory>('neighbornet_get_chat_history_json');
    _postBulletin = _dylib!.lookupFunction<_NativePostBulletin, _DartPostBulletin>('neighbornet_post_bulletin');
    _getBulletinsJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_bulletins_json');
    _freeString = _dylib!.lookupFunction<_NativeFreeString, _DartFreeString>('neighbornet_free_string');

    _publishFile = _dylib!.lookupFunction<_NativePublishFile, _DartPublishFile>('neighbornet_publish_file');
    _getSharedFilesJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_shared_files_json');
    _requestFile = _dylib!.lookupFunction<_NativeRequestFile, _DartRequestFile>('neighbornet_request_file');
    _getFilePath = _dylib!.lookupFunction<_NativeGetFilePath, _DartGetFilePath>('neighbornet_get_file_path');

    _createRoom = _dylib!.lookupFunction<_NativeCreateRoom, _DartCreateRoom>('neighbornet_create_room');
    _getRoomsJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_rooms_json');
    _proposeVote = _dylib!.lookupFunction<_NativeProposeVote, _DartProposeVote>('neighbornet_propose_steward_vote');
    _castVote = _dylib!.lookupFunction<_NativeCastVote, _DartCastVote>('neighbornet_cast_vote');
    _getProposalsJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_proposals_json');
    _getAuditLogJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_audit_log_json');
  }

  bool initNode({String? dataDir, int listenPort = 42424, bool isTransport = false}) {
    _loadLibrary();
    final dirPtr = dataDir != null ? dataDir.toNativeUtf8() : nullptr;
    try {
      _isInitialized = _init(dirPtr, listenPort, isTransport);
      return _isInitialized;
    } finally {
      if (dirPtr != nullptr) calloc.free(dirPtr);
    }
  }

  void stopNode() {
    if (_isInitialized) {
      _stop();
      _isInitialized = false;
    }
  }

  NodeStatus? getStatus() {
    if (!_isInitialized) return null;
    final ptr = _getStatusJson();
    if (ptr == nullptr) return null;
    try {
      final jsonStr = ptr.toDartString();
      if (jsonStr.isEmpty) return null;
      return NodeStatus.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } finally {
      _freeString(ptr);
    }
  }

  bool setNickname(String nickname) {
    if (!_isInitialized) return false;
    final namePtr = nickname.toNativeUtf8();
    try {
      return _setNickname(namePtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  List<PeerInfo> getPeers() {
    if (!_isInitialized) return [];
    final ptr = _getPeersJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => PeerInfo.fromJson(item as Map<String, dynamic>)).toList();
    } finally {
      _freeString(ptr);
    }
  }

  bool sendChat(String channel, String content) {
    if (!_isInitialized) return false;
    final chPtr = channel.toNativeUtf8();
    final contentPtr = content.toNativeUtf8();
    try {
      return _sendChat(chPtr, contentPtr);
    } finally {
      calloc.free(chPtr);
      calloc.free(contentPtr);
    }
  }

  List<ChatMessage> getChatHistory(String channel) {
    if (!_isInitialized) return [];
    final chPtr = channel.toNativeUtf8();
    try {
      final ptr = _getChatHistoryJson(chPtr);
      if (ptr == nullptr) return [];
      try {
        final jsonStr = ptr.toDartString();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(chPtr);
    }
  }

  bool postBulletin(String title, String body, String urgency) {
    if (!_isInitialized) return false;
    final titlePtr = title.toNativeUtf8();
    final bodyPtr = body.toNativeUtf8();
    final urgencyPtr = urgency.toNativeUtf8();
    try {
      return _postBulletin(titlePtr, bodyPtr, urgencyPtr);
    } finally {
      calloc.free(titlePtr);
      calloc.free(bodyPtr);
      calloc.free(urgencyPtr);
    }
  }

  List<BulletinPost> getBulletins() {
    if (!_isInitialized) return [];
    final ptr = _getBulletinsJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => BulletinPost.fromJson(item as Map<String, dynamic>)).toList();
    } finally {
      _freeString(ptr);
    }
  }

  String? publishFile(String filePath, String description) {
    if (!_isInitialized) return null;
    final pathPtr = filePath.toNativeUtf8();
    final descPtr = description.toNativeUtf8();
    try {
      final ptr = _publishFile(pathPtr, descPtr);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(descPtr);
    }
  }

  List<SharedFileInfo> getSharedFiles() {
    if (!_isInitialized) return [];
    final ptr = _getSharedFilesJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => SharedFileInfo.fromJson(item as Map<String, dynamic>)).toList();
    } finally {
      _freeString(ptr);
    }
  }

  bool requestFile(String fileHash) {
    if (!_isInitialized) return false;
    final hashPtr = fileHash.toNativeUtf8();
    try {
      return _requestFile(hashPtr);
    } finally {
      calloc.free(hashPtr);
    }
  }

  String? getCompletedFilePath(String fileHash) {
    if (!_isInitialized) return null;
    final hashPtr = fileHash.toNativeUtf8();
    try {
      final ptr = _getFilePath(hashPtr);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(hashPtr);
    }
  }

  RoomInfo? createRoom(String name, String description, {bool isPrivate = false}) {
    if (!_isInitialized) return null;
    final namePtr = name.toNativeUtf8();
    final descPtr = description.toNativeUtf8();
    try {
      final ptr = _createRoom(namePtr, descPtr, isPrivate);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        return RoomInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(namePtr);
      calloc.free(descPtr);
    }
  }

  List<RoomInfo> getRooms() {
    if (!_isInitialized) return [];
    final ptr = _getRoomsJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => RoomInfo.fromJson(item as Map<String, dynamic>)).toList();
    } finally {
      _freeString(ptr);
    }
  }

  String? proposeStewardVote({
    required String roomId,
    required String targetHash,
    required String targetNickname,
    required String action,
    required String reasonCategory,
    required String reasonDetails,
  }) {
    if (!_isInitialized) return null;
    final rPtr = roomId.toNativeUtf8();
    final thPtr = targetHash.toNativeUtf8();
    final tnPtr = targetNickname.toNativeUtf8();
    final aPtr = action.toNativeUtf8();
    final rcPtr = reasonCategory.toNativeUtf8();
    final rdPtr = reasonDetails.toNativeUtf8();
    try {
      final ptr = _proposeVote(rPtr, thPtr, tnPtr, aPtr, rcPtr, rdPtr);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(rPtr);
      calloc.free(thPtr);
      calloc.free(tnPtr);
      calloc.free(aPtr);
      calloc.free(rcPtr);
      calloc.free(rdPtr);
    }
  }

  bool castVote(String proposalId, bool approve) {
    if (!_isInitialized) return false;
    final propPtr = proposalId.toNativeUtf8();
    try {
      return _castVote(propPtr, approve);
    } finally {
      calloc.free(propPtr);
    }
  }

  List<StewardVoteInfo> getProposals(String roomId) {
    if (!_isInitialized) return [];
    final rPtr = roomId.toNativeUtf8();
    try {
      final ptr = _getProposalsJson(rPtr);
      if (ptr == nullptr) return [];
      try {
        final jsonStr = ptr.toDartString();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((item) => StewardVoteInfo.fromJson(item as Map<String, dynamic>)).toList();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(rPtr);
    }
  }

  List<GovernanceEventInfo> getAuditLog(String roomId) {
    if (!_isInitialized) return [];
    final rPtr = roomId.toNativeUtf8();
    try {
      final ptr = _getAuditLogJson(rPtr);
      if (ptr == nullptr) return [];
      try {
        final jsonStr = ptr.toDartString();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((item) => GovernanceEventInfo.fromJson(item as Map<String, dynamic>)).toList();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(rPtr);
    }
  }
}
