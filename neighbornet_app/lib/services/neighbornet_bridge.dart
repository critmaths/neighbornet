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

typedef _NativePanicWipe = Bool Function();
typedef _DartPanicWipe = bool Function();

typedef _NativeExportMnemonic = Pointer<Utf8> Function();
typedef _DartExportMnemonic = Pointer<Utf8> Function();

typedef _NativeRestoreIdentity = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartRestoreIdentity = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _NativeListSerialPorts = Pointer<Utf8> Function();
typedef _DartListSerialPorts = Pointer<Utf8> Function();

typedef _NativeConnectLora = Bool Function(Pointer<Utf8>, Uint32, Uint32, Uint32, Uint8, Uint8);
typedef _DartConnectLora = bool Function(Pointer<Utf8>, int, int, int, int, int);

typedef _NativeDisconnectLora = Bool Function();
typedef _DartDisconnectLora = bool Function();

typedef _NativeGetLoraStatus = Pointer<Utf8> Function();
typedef _DartGetLoraStatus = Pointer<Utf8> Function();

typedef _NativeSendLoraPacket = Bool Function(Pointer<Utf8>);
typedef _DartSendLoraPacket = bool Function(Pointer<Utf8>);

typedef _NativeCreateFormSchema = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);
typedef _DartCreateFormSchema = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);

typedef _NativeSubmitFormEntry = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DartSubmitFormEntry = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _NativeSendPttChunk = Bool Function(Pointer<Utf8>, Uint32, Pointer<Utf8>, Pointer<Utf8>, Bool, Pointer<Utf8>);
typedef _DartSendPttChunk = bool Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>, bool, Pointer<Utf8>);

typedef _NativeSendPttFloor = Bool Function(Pointer<Utf8>, Bool, Pointer<Utf8>);
typedef _DartSendPttFloor = bool Function(Pointer<Utf8>, bool, Pointer<Utf8>);

typedef _NativeSendVoiceChat = Bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Uint32);
typedef _DartSendVoiceChat = bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);

typedef _NativeDeleteMarker = Bool Function(Pointer<Utf8>);
typedef _DartDeleteMarker = bool Function(Pointer<Utf8>);

typedef _NativeInitiateTraceroute = Pointer<Utf8> Function(Pointer<Utf8>, Uint8);
typedef _DartInitiateTraceroute = Pointer<Utf8> Function(Pointer<Utf8>, int);

typedef _NativeGetTracerouteById = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartGetTracerouteById = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _NativeSimulateTrace = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartSimulateTrace = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _NativePublishFileExtended = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);
typedef _DartPublishFileExtended = Pointer<Utf8> Function(
  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>
);

typedef _NativeExportFile = Bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _DartExportFile = bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

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
  late _DartPublishFileExtended _publishFileExtended;
  late _DartGetJson _getSharedFilesJson;
  late _DartRequestFile _requestFile;
  late _DartGetFilePath _getFilePath;
  late _DartGetRoomData _getFileChunkStatusJson;
  late _DartDeleteMarker _deleteFile;
  late _DartExportFile _exportFile;

  late _DartCreateRoom _createRoom;
  late _DartGetJson _getRoomsJson;
  late _DartProposeVote _proposeVote;
  late _DartCastVote _castVote;
  late _DartGetRoomData _getProposalsJson;
  late _DartGetRoomData _getAuditLogJson;

  late _DartPanicWipe _panicWipe;
  late _DartExportMnemonic _exportIdentityMnemonic;
  late _DartRestoreIdentity _restoreIdentity;

  late _DartListSerialPorts _listSerialPorts;
  late _DartConnectLora _connectLora;
  late _DartDisconnectLora _disconnectLora;
  late _DartGetLoraStatus _getLoraStatus;
  late _DartSendLoraPacket _sendLoraPacket;

  late _DartGetJson _getFormSchemasJson;
  late _DartCreateFormSchema _createFormSchema;
  late _DartGetRoomData _getFormEntriesJson;
  late _DartSubmitFormEntry _submitFormEntry;

  late _DartGetJson _getMyProfileJson;
  late _DartGetRoomData _updateMyProfile;
  late _DartGetRoomData _getPeerProfileJson;
  late _DartGetJson _getAllProfilesJson;

  late _DartSendPttChunk _sendPttChunk;
  late _DartSendPttFloor _sendPttFloor;

  late _DartSendVoiceChat _sendVoiceChat;
  late _DartGetJson _getMarkersJson;
  late _DartGetRoomData _upsertMarker;
  late _DartDeleteMarker _deleteMarker;

  late _DartInitiateTraceroute _initiateTraceroute;
  late _DartGetJson _getTraceroutesJson;
  late _DartGetTracerouteById _getTracerouteById;
  late _DartSimulateTrace _simulateTrace;

  bool get isReady => _isInitialized;

  void _loadLibrary() {
    if (_dylib != null) return;

    final candidatePaths = <String>[
      if (Platform.environment.containsKey('NEIGHBORNET_CORE_LIB'))
        Platform.environment['NEIGHBORNET_CORE_LIB']!,
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}neighbornet_core.dll',
      r'C:\Users\criti\RiderProjects\Neighbornet\neighbornet_core\target\release\neighbornet_core.dll',
      r'C:\Users\criti\RiderProjects\Neighbornet\neighbornet_core\target\debug\neighbornet_core.dll',
      r'neighbornet_core.dll',
      'libneighbornet_core.dylib',
      'libneighbornet_core.so',
    ];

    for (final path in candidatePaths) {
      try {
        _dylib = DynamicLibrary.open(path);
        break;
      } catch (_) {}
    }

    if (_dylib == null) {
      return;
    }

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
    _publishFileExtended = _dylib!.lookupFunction<_NativePublishFileExtended, _DartPublishFileExtended>('neighbornet_publish_file_extended');
    _getSharedFilesJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_shared_files_json');
    _requestFile = _dylib!.lookupFunction<_NativeRequestFile, _DartRequestFile>('neighbornet_request_file');
    _getFilePath = _dylib!.lookupFunction<_NativeGetFilePath, _DartGetFilePath>('neighbornet_get_file_path');
    _getFileChunkStatusJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_file_chunk_status_json');
    _deleteFile = _dylib!.lookupFunction<_NativeDeleteMarker, _DartDeleteMarker>('neighbornet_delete_file');
    _exportFile = _dylib!.lookupFunction<_NativeExportFile, _DartExportFile>('neighbornet_export_file');

    _createRoom = _dylib!.lookupFunction<_NativeCreateRoom, _DartCreateRoom>('neighbornet_create_room');
    _getRoomsJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_rooms_json');
    _proposeVote = _dylib!.lookupFunction<_NativeProposeVote, _DartProposeVote>('neighbornet_propose_steward_vote');
    _castVote = _dylib!.lookupFunction<_NativeCastVote, _DartCastVote>('neighbornet_cast_vote');
    _getProposalsJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_proposals_json');
    _getAuditLogJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_audit_log_json');

    _panicWipe = _dylib!.lookupFunction<_NativePanicWipe, _DartPanicWipe>('neighbornet_panic_wipe');
    _exportIdentityMnemonic = _dylib!.lookupFunction<_NativeExportMnemonic, _DartExportMnemonic>('neighbornet_export_identity_mnemonic');
    _restoreIdentity = _dylib!.lookupFunction<_NativeRestoreIdentity, _DartRestoreIdentity>('neighbornet_restore_identity');

    _listSerialPorts = _dylib!.lookupFunction<_NativeListSerialPorts, _DartListSerialPorts>('neighbornet_list_serial_ports_json');
    _connectLora = _dylib!.lookupFunction<_NativeConnectLora, _DartConnectLora>('neighbornet_connect_lora');
    _disconnectLora = _dylib!.lookupFunction<_NativeDisconnectLora, _DartDisconnectLora>('neighbornet_disconnect_lora');
    _getLoraStatus = _dylib!.lookupFunction<_NativeGetLoraStatus, _DartGetLoraStatus>('neighbornet_get_lora_status_json');
    _sendLoraPacket = _dylib!.lookupFunction<_NativeSendLoraPacket, _DartSendLoraPacket>('neighbornet_send_lora_packet');

    _getFormSchemasJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_form_schemas_json');
    _createFormSchema = _dylib!.lookupFunction<_NativeCreateFormSchema, _DartCreateFormSchema>('neighbornet_create_form_schema');
    _getFormEntriesJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_form_entries_json');
    _submitFormEntry = _dylib!.lookupFunction<_NativeSubmitFormEntry, _DartSubmitFormEntry>('neighbornet_submit_form_entry');

    _getMyProfileJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_my_profile_json');
    _updateMyProfile = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_update_my_profile');
    _getPeerProfileJson = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_get_peer_profile_json');
    _getAllProfilesJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_all_profiles_json');

    _sendPttChunk = _dylib!.lookupFunction<_NativeSendPttChunk, _DartSendPttChunk>('neighbornet_send_ptt_chunk');
    _sendPttFloor = _dylib!.lookupFunction<_NativeSendPttFloor, _DartSendPttFloor>('neighbornet_send_ptt_floor');

    _sendVoiceChat = _dylib!.lookupFunction<_NativeSendVoiceChat, _DartSendVoiceChat>('neighbornet_send_voice_chat');
    _getMarkersJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_markers_json');
    _upsertMarker = _dylib!.lookupFunction<_NativeGetRoomData, _DartGetRoomData>('neighbornet_upsert_marker');
    _deleteMarker = _dylib!.lookupFunction<_NativeDeleteMarker, _DartDeleteMarker>('neighbornet_delete_marker');

    _initiateTraceroute = _dylib!.lookupFunction<_NativeInitiateTraceroute, _DartInitiateTraceroute>('neighbornet_initiate_traceroute');
    _getTraceroutesJson = _dylib!.lookupFunction<_NativeGetJson, _DartGetJson>('neighbornet_get_traceroutes_json');
    _getTracerouteById = _dylib!.lookupFunction<_NativeGetTracerouteById, _DartGetTracerouteById>('neighbornet_get_traceroute_by_id_json');
    _simulateTrace = _dylib!.lookupFunction<_NativeSimulateTrace, _DartSimulateTrace>('neighbornet_simulate_trace');
  }

  bool initNode({String? dataDir, int listenPort = 42424, bool isTransport = false}) {
    _loadLibrary();
    if (_dylib == null) return false;
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
    final cPtr = content.toNativeUtf8();
    try {
      return _sendChat(chPtr, cPtr);
    } finally {
      calloc.free(chPtr);
      calloc.free(cPtr);
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

  bool postBulletin(String title, String body, [String urgency = 'normal']) {
    if (!_isInitialized) return false;
    final tPtr = title.toNativeUtf8();
    final bPtr = body.toNativeUtf8();
    final uPtr = urgency.toNativeUtf8();
    try {
      return _postBulletin(tPtr, bPtr, uPtr);
    } finally {
      calloc.free(tPtr);
      calloc.free(bPtr);
      calloc.free(uPtr);
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

  String? publishFileExtended({
    required String filePath,
    required String description,
    String category = 'documents',
    String groupTag = 'Public Vault',
    String? passphrase,
  }) {
    if (!_isInitialized) return null;
    final pathPtr = filePath.toNativeUtf8();
    final descPtr = description.toNativeUtf8();
    final catPtr = category.toNativeUtf8();
    final tagPtr = groupTag.toNativeUtf8();
    final passPtr = passphrase != null && passphrase.isNotEmpty ? passphrase.toNativeUtf8() : nullptr;
    try {
      final ptr = _publishFileExtended(pathPtr, descPtr, catPtr, tagPtr, passPtr);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(pathPtr);
      calloc.free(descPtr);
      calloc.free(catPtr);
      calloc.free(tagPtr);
      if (passPtr != nullptr) calloc.free(passPtr);
    }
  }

  FileChunkProgress? getFileChunkStatus(String fileHash) {
    if (!_isInitialized) return null;
    final hashPtr = fileHash.toNativeUtf8();
    try {
      final ptr = _getFileChunkStatusJson(hashPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return FileChunkProgress.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(hashPtr);
    }
  }

  bool deleteFile(String fileHash) {
    if (!_isInitialized) return false;
    final hashPtr = fileHash.toNativeUtf8();
    try {
      return _deleteFile(hashPtr);
    } catch (_) {
      return false;
    } finally {
      calloc.free(hashPtr);
    }
  }

  bool exportFile({
    required String fileHash,
    required String targetPath,
    String? passphrase,
  }) {
    if (!_isInitialized) return false;
    final hashPtr = fileHash.toNativeUtf8();
    final targetPtr = targetPath.toNativeUtf8();
    final passPtr = passphrase != null && passphrase.isNotEmpty ? passphrase.toNativeUtf8() : nullptr;
    try {
      return _exportFile(hashPtr, targetPtr, passPtr);
    } catch (_) {
      return false;
    } finally {
      calloc.free(hashPtr);
      calloc.free(targetPtr);
      if (passPtr != nullptr) calloc.free(passPtr);
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

  bool panicWipe() {
    if (!_isInitialized) return false;
    return _panicWipe();
  }

  String? exportIdentityMnemonic() {
    if (!_isInitialized) return null;
    final ptr = _exportIdentityMnemonic();
    if (ptr == nullptr) return null;
    try {
      return ptr.toDartString();
    } finally {
      _freeString(ptr);
    }
  }

  String? restoreIdentity(String phraseOrHex) {
    if (!_isInitialized) return null;
    final inputPtr = phraseOrHex.toNativeUtf8();
    try {
      final ptr = _restoreIdentity(inputPtr);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        _freeString(ptr);
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  List<SerialDeviceInfo> listSerialPorts() {
    if (!_isInitialized) return [];
    final ptr = _listSerialPorts();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => SerialDeviceInfo.fromJson(item as Map<String, dynamic>)).toList();
    } finally {
      _freeString(ptr);
    }
  }

  bool connectLora({
    required String portName,
    int baudRate = 115200,
    int freqHz = 915000000,
    int bwHz = 125000,
    int sf = 10,
    int cr = 5,
  }) {
    if (!_isInitialized) return false;
    final portPtr = portName.toNativeUtf8();
    try {
      return _connectLora(portPtr, baudRate, freqHz, bwHz, sf, cr);
    } finally {
      calloc.free(portPtr);
    }
  }

  bool disconnectLora() {
    if (!_isInitialized) return false;
    return _disconnectLora();
  }

  LoraRadioStatus? getLoraStatus() {
    if (!_isInitialized) return null;
    final ptr = _getLoraStatus();
    if (ptr == nullptr) return null;
    try {
      final jsonStr = ptr.toDartString();
      if (jsonStr.isEmpty) return null;
      return LoraRadioStatus.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } finally {
      _freeString(ptr);
    }
  }

  bool sendLoraPacket(String payload) {
    if (!_isInitialized) return false;
    final payloadPtr = payload.toNativeUtf8();
    try {
      return _sendLoraPacket(payloadPtr);
    } finally {
      calloc.free(payloadPtr);
    }
  }

  List<FormSchema> getFormSchemas() {
    if (!_isInitialized) return [];
    final ptr = _getFormSchemasJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => FormSchema.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    } finally {
      _freeString(ptr);
    }
  }

  FormSchema? createFormSchema({
    required String title,
    required String description,
    required String category,
    required List<FormFieldDef> fields,
  }) {
    if (!_isInitialized) return null;
    final titlePtr = title.toNativeUtf8();
    final descPtr = description.toNativeUtf8();
    final catPtr = category.toNativeUtf8();
    final fieldsJson = jsonEncode(fields.map((f) => f.toJson()).toList());
    final fieldsPtr = fieldsJson.toNativeUtf8();

    try {
      final ptr = _createFormSchema(titlePtr, descPtr, catPtr, fieldsPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return FormSchema.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(titlePtr);
      calloc.free(descPtr);
      calloc.free(catPtr);
      calloc.free(fieldsPtr);
    }
  }

  List<FormEntry> getFormEntries(String schemaId) {
    if (!_isInitialized) return [];
    final schemaIdPtr = schemaId.toNativeUtf8();
    try {
      final ptr = _getFormEntriesJson(schemaIdPtr);
      if (ptr == nullptr) return [];
      try {
        final jsonStr = ptr.toDartString();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((item) => FormEntry.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return [];
    } finally {
      calloc.free(schemaIdPtr);
    }
  }

  FormEntry? submitFormEntry(String schemaId, Map<String, dynamic> data) {
    if (!_isInitialized) return null;
    final schemaIdPtr = schemaId.toNativeUtf8();
    final dataJson = jsonEncode(data);
    final dataPtr = dataJson.toNativeUtf8();

    try {
      final ptr = _submitFormEntry(schemaIdPtr, dataPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return FormEntry.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(schemaIdPtr);
      calloc.free(dataPtr);
    }
  }

  UserProfile? getMyProfile() {
    if (!_isInitialized) return null;
    final ptr = _getMyProfileJson();
    if (ptr == nullptr) return null;
    try {
      final jsonStr = ptr.toDartString();
      if (jsonStr.isEmpty || jsonStr == '{}') return null;
      return UserProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    } finally {
      _freeString(ptr);
    }
  }

  UserProfile? updateMyProfile(UserProfile profile) {
    if (!_isInitialized) return null;
    final jsonStr = jsonEncode(profile.toJson());
    final jsonPtr = jsonStr.toNativeUtf8();
    try {
      final ptr = _updateMyProfile(jsonPtr);
      if (ptr == nullptr) return null;
      try {
        final resStr = ptr.toDartString();
        final map = jsonDecode(resStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return UserProfile.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(jsonPtr);
    }
  }

  UserProfile? getPeerProfile(String destHash) {
    if (!_isInitialized) return null;
    final hashPtr = destHash.toNativeUtf8();
    try {
      final ptr = _getPeerProfileJson(hashPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        if (jsonStr.isEmpty || jsonStr == 'null' || jsonStr == '{}') return null;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserProfile.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(hashPtr);
    }
  }

  List<UserProfile> getAllProfiles() {
    if (!_isInitialized) return [];
    final ptr = _getAllProfilesJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => UserProfile.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    } finally {
      _freeString(ptr);
    }
  }

  bool sendPttChunk({
    required String sessionId,
    required int sequence,
    required String channel,
    required String audioBase64,
    required bool isFinal,
    String priority = 'normal',
  }) {
    if (!_isInitialized) return false;
    final sessPtr = sessionId.toNativeUtf8();
    final chanPtr = channel.toNativeUtf8();
    final audioPtr = audioBase64.toNativeUtf8();
    final prioPtr = priority.toNativeUtf8();
    try {
      return _sendPttChunk(sessPtr, sequence, chanPtr, audioPtr, isFinal, prioPtr);
    } catch (_) {
      return false;
    } finally {
      calloc.free(sessPtr);
      calloc.free(chanPtr);
      calloc.free(audioPtr);
      calloc.free(prioPtr);
    }
  }

  bool sendPttFloor({
    required String channel,
    required bool isTransmitting,
    String priority = 'normal',
  }) {
    if (!_isInitialized) return false;
    final chanPtr = channel.toNativeUtf8();
    final prioPtr = priority.toNativeUtf8();
    try {
      return _sendPttFloor(chanPtr, isTransmitting, prioPtr);
    } catch (_) {
      return false;
    } finally {
      calloc.free(chanPtr);
      calloc.free(prioPtr);
    }
  }

  bool sendVoiceChat({
    required String channel,
    required String content,
    String? audioBase64,
    int? audioDurationSec,
  }) {
    if (!_isInitialized) return false;
    final chPtr = channel.toNativeUtf8();
    final cPtr = content.toNativeUtf8();
    final audioPtr = audioBase64 != null ? audioBase64.toNativeUtf8() : nullptr;
    try {
      return _sendVoiceChat(chPtr, cPtr, audioPtr, audioDurationSec ?? 0);
    } catch (_) {
      return false;
    } finally {
      calloc.free(chPtr);
      calloc.free(cPtr);
      if (audioPtr != nullptr) calloc.free(audioPtr);
    }
  }

  List<TacticalMarker> getMarkers() {
    if (!_isInitialized) return [];
    final ptr = _getMarkersJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => TacticalMarker.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    } finally {
      _freeString(ptr);
    }
  }

  TacticalMarker? upsertMarker(TacticalMarker marker) {
    if (!_isInitialized) return null;
    final jsonStr = jsonEncode(marker.toJson());
    final jsonPtr = jsonStr.toNativeUtf8();
    try {
      final ptr = _upsertMarker(jsonPtr);
      if (ptr == nullptr) return null;
      try {
        final resStr = ptr.toDartString();
        final map = jsonDecode(resStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return TacticalMarker.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(jsonPtr);
    }
  }

  bool deleteMarker(String markerId) {
    if (!_isInitialized) return false;
    final idPtr = markerId.toNativeUtf8();
    try {
      return _deleteMarker(idPtr);
    } catch (_) {
      return false;
    } finally {
      calloc.free(idPtr);
    }
  }

  TracerouteSession? initiateTraceroute(String targetHash, {int maxTtl = 8}) {
    if (!_isInitialized) return null;
    final hashPtr = targetHash.toNativeUtf8();
    try {
      final ptr = _initiateTraceroute(hashPtr, maxTtl);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return TracerouteSession.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(hashPtr);
    }
  }

  List<TracerouteSession> getTraceroutes() {
    if (!_isInitialized) return [];
    final ptr = _getTraceroutesJson();
    if (ptr == nullptr) return [];
    try {
      final jsonStr = ptr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => TracerouteSession.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    } finally {
      _freeString(ptr);
    }
  }

  TracerouteSession? getTracerouteById(String traceId) {
    if (!_isInitialized) return null;
    final idPtr = traceId.toNativeUtf8();
    try {
      final ptr = _getTracerouteById(idPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        if (jsonStr == 'null' || jsonStr.isEmpty) return null;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TracerouteSession.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(idPtr);
    }
  }

  TracerouteSession? simulateTrace(String targetHash) {
    if (!_isInitialized) return null;
    final hashPtr = targetHash.toNativeUtf8();
    try {
      final ptr = _simulateTrace(hashPtr);
      if (ptr == nullptr) return null;
      try {
        final jsonStr = ptr.toDartString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return TracerouteSession.fromJson(map);
      } finally {
        _freeString(ptr);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(hashPtr);
    }
  }
}
