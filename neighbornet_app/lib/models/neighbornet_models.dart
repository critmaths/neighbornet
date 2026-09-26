import 'dart:convert';

class NodeStatus {
  final String destHash;
  final String nickname;
  final int listenPort;
  final bool isTransport;
  final int peerCount;
  final int bulletinCount;
  final int fileCount;
  final int roomCount;
  final int uptimeSec;

  NodeStatus({
    required this.destHash,
    required this.nickname,
    required this.listenPort,
    required this.isTransport,
    required this.peerCount,
    required this.bulletinCount,
    this.fileCount = 0,
    this.roomCount = 0,
    required this.uptimeSec,
  });

  factory NodeStatus.fromJson(Map<String, dynamic> json) {
    return NodeStatus(
      destHash: json['dest_hash'] ?? '',
      nickname: json['nickname'] ?? 'Anonymous',
      listenPort: json['listen_port'] ?? 0,
      isTransport: json['is_transport'] ?? false,
      peerCount: json['peer_count'] ?? 0,
      bulletinCount: json['bulletin_count'] ?? 0,
      fileCount: json['file_count'] ?? 0,
      roomCount: json['room_count'] ?? 0,
      uptimeSec: json['uptime_sec'] ?? 0,
    );
  }
}

class PeerInfo {
  final String destHash;
  final String nickname;
  final String addr;
  final bool isTransport;
  final int lastSeenEpochSec;

  PeerInfo({
    required this.destHash,
    required this.nickname,
    required this.addr,
    required this.isTransport,
    required this.lastSeenEpochSec,
  });

  factory PeerInfo.fromJson(Map<String, dynamic> json) {
    return PeerInfo(
      destHash: json['dest_hash'] ?? '',
      nickname: json['nickname'] ?? 'Unknown Peer',
      addr: json['addr'] ?? '',
      isTransport: json['is_transport'] ?? false,
      lastSeenEpochSec: json['last_seen_epoch_sec'] ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String channel;
  final String senderHash;
  final String senderNickname;
  final String content;
  final int timestampSec;
  final String? audioBase64;
  final int? audioDurationSec;

  ChatMessage({
    required this.id,
    required this.channel,
    required this.senderHash,
    required this.senderNickname,
    required this.content,
    required this.timestampSec,
    this.audioBase64,
    this.audioDurationSec,
  });

  bool get isVoiceMemo => audioBase64 != null && audioBase64!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      channel: json['channel'] ?? 'general',
      senderHash: json['sender_hash'] ?? '',
      senderNickname: json['sender_nickname'] ?? 'Neighbor',
      content: json['content'] ?? '',
      timestampSec: json['timestamp_sec'] ?? 0,
      audioBase64: json['audio_base64'],
      audioDurationSec: json['audio_duration_sec'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel': channel,
      'sender_hash': senderHash,
      'sender_nickname': senderNickname,
      'content': content,
      'timestamp_sec': timestampSec,
      if (audioBase64 != null) 'audio_base64': audioBase64,
      if (audioDurationSec != null) 'audio_duration_sec': audioDurationSec,
    };
  }
}

class TacticalMarker {
  final String id;
  final String title;
  final String category; // "medical", "water", "shelter", "hazard", "checkpoint", "relay", "sos"
  final String description;
  final double lat;
  final double lon;
  final String authorHash;
  final String authorNickname;
  final String authorCallsign;
  final int timestampSec;
  final bool isActive;

  TacticalMarker({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.lat,
    required this.lon,
    required this.authorHash,
    required this.authorNickname,
    required this.authorCallsign,
    required this.timestampSec,
    this.isActive = true,
  });

  factory TacticalMarker.fromJson(Map<String, dynamic> json) {
    return TacticalMarker(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'medical',
      description: json['description'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      authorHash: json['author_hash'] ?? '',
      authorNickname: json['author_nickname'] ?? '',
      authorCallsign: json['author_callsign'] ?? '',
      timestampSec: json['timestamp_sec'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'lat': lat,
      'lon': lon,
      'author_hash': authorHash,
      'author_nickname': authorNickname,
      'author_callsign': authorCallsign,
      'timestamp_sec': timestampSec,
      'is_active': isActive,
    };
  }
}

class TraceHop {
  final String nodeHash;
  final String nickname;
  final String callsign;
  final String interfaceType; // "UDP/LAN", "LoRa-915MHz", "BLE-Mesh", "Local Host"
  final int? rssiDbm;
  final double? snrDb;
  final int timestampMs;
  final int deltaMs;

  TraceHop({
    required this.nodeHash,
    required this.nickname,
    required this.callsign,
    required this.interfaceType,
    this.rssiDbm,
    this.snrDb,
    required this.timestampMs,
    required this.deltaMs,
  });

  factory TraceHop.fromJson(Map<String, dynamic> json) {
    return TraceHop(
      nodeHash: json['node_hash'] ?? '',
      nickname: json['nickname'] ?? 'Unknown Node',
      callsign: json['callsign'] ?? '',
      interfaceType: json['interface_type'] ?? 'UDP/LAN',
      rssiDbm: json['rssi_dbm'],
      snrDb: (json['snr_db'] as num?)?.toDouble(),
      timestampMs: json['timestamp_ms'] ?? 0,
      deltaMs: json['delta_ms'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_hash': nodeHash,
      'nickname': nickname,
      'callsign': callsign,
      'interface_type': interfaceType,
      if (rssiDbm != null) 'rssi_dbm': rssiDbm,
      if (snrDb != null) 'snr_db': snrDb,
      'timestamp_ms': timestampMs,
      'delta_ms': deltaMs,
    };
  }
}

class TracerouteSession {
  final String traceId;
  final String originHash;
  final String originNickname;
  final String originCallsign;
  final String targetHash;
  final String targetNickname;
  final int ttl;
  final int maxTtl;
  final List<TraceHop> hops;
  final String status; // "in_transit", "reached_destination", "ttl_expired", "timeout"
  final int createdAtMs;
  final int? completedAtMs;
  final int? totalRttMs;

  TracerouteSession({
    required this.traceId,
    required this.originHash,
    required this.originNickname,
    required this.originCallsign,
    required this.targetHash,
    required this.targetNickname,
    required this.ttl,
    required this.maxTtl,
    required this.hops,
    required this.status,
    required this.createdAtMs,
    this.completedAtMs,
    this.totalRttMs,
  });

  bool get isCompleted => status == 'reached_destination' || status == 'ttl_expired' || status == 'timeout';
  bool get isSuccess => status == 'reached_destination';

  factory TracerouteSession.fromJson(Map<String, dynamic> json) {
    var rawHops = json['hops'] as List? ?? [];
    List<TraceHop> hopsList = rawHops.map((h) => TraceHop.fromJson(h as Map<String, dynamic>)).toList();

    return TracerouteSession(
      traceId: json['trace_id'] ?? '',
      originHash: json['origin_hash'] ?? '',
      originNickname: json['origin_nickname'] ?? 'Origin',
      originCallsign: json['origin_callsign'] ?? '',
      targetHash: json['target_hash'] ?? '',
      targetNickname: json['target_nickname'] ?? 'Target',
      ttl: json['ttl'] ?? 0,
      maxTtl: json['max_ttl'] ?? 8,
      hops: hopsList,
      status: json['status'] ?? 'in_transit',
      createdAtMs: json['created_at_ms'] ?? 0,
      completedAtMs: json['completed_at_ms'],
      totalRttMs: json['total_rtt_ms'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trace_id': traceId,
      'origin_hash': originHash,
      'origin_nickname': originNickname,
      'origin_callsign': originCallsign,
      'target_hash': targetHash,
      'target_nickname': targetNickname,
      'ttl': ttl,
      'max_ttl': maxTtl,
      'hops': hops.map((h) => h.toJson()).toList(),
      'status': status,
      'created_at_ms': createdAtMs,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      if (totalRttMs != null) 'total_rtt_ms': totalRttMs,
    };
  }
}

class BulletinPost {
  final String id;
  final String title;
  final String body;
  final String urgency;
  final String authorHash;
  final String authorNickname;
  final int timestampSec;

  BulletinPost({
    required this.id,
    required this.title,
    required this.body,
    required this.urgency,
    required this.authorHash,
    required this.authorNickname,
    required this.timestampSec,
  });

  factory BulletinPost.fromJson(Map<String, dynamic> json) {
    return BulletinPost(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      urgency: json['urgency'] ?? 'normal',
      authorHash: json['author_hash'] ?? '',
      authorNickname: json['author_nickname'] ?? 'Community',
      timestampSec: json['timestamp_sec'] ?? 0,
    );
  }
}

class SharedFileInfo {
  final String fileHash;
  final String fileName;
  final int fileSizeBytes;
  final int chunkCount;
  final int chunkSize;
  final String description;
  final String authorHash;
  final String authorNickname;
  final int timestampSec;
  final bool isComplete;
  final String category;
  final String groupTag;
  final bool isEncrypted;
  final String mimeType;
  final String encryptionSalt;

  SharedFileInfo({
    required this.fileHash,
    required this.fileName,
    required this.fileSizeBytes,
    required this.chunkCount,
    required this.chunkSize,
    required this.description,
    required this.authorHash,
    required this.authorNickname,
    required this.timestampSec,
    required this.isComplete,
    this.category = 'documents',
    this.groupTag = 'Public Vault',
    this.isEncrypted = false,
    this.mimeType = 'application/octet-stream',
    this.encryptionSalt = '',
  });

  factory SharedFileInfo.fromJson(Map<String, dynamic> json) {
    return SharedFileInfo(
      fileHash: json['file_hash'] as String? ?? '',
      fileName: json['filename'] as String? ?? 'unknown',
      fileSizeBytes: (json['file_size'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 1,
      chunkSize: (json['chunk_size'] as num?)?.toInt() ?? 8192,
      description: json['description'] as String? ?? '',
      authorHash: json['author_hash'] as String? ?? '',
      authorNickname: json['author_nickname'] as String? ?? 'Anonymous',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? 0,
      isComplete: json['is_complete'] as bool? ?? false,
      category: json['category'] as String? ?? 'documents',
      groupTag: json['group_tag'] as String? ?? 'Public Vault',
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      encryptionSalt: json['encryption_salt'] as String? ?? '',
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class FileChunkProgress {
  final String fileHash;
  final String filename;
  final int downloadedChunks;
  final int totalChunks;
  final double progressPercent;
  final bool isComplete;
  final String? filePath;

  FileChunkProgress({
    required this.fileHash,
    required this.filename,
    required this.downloadedChunks,
    required this.totalChunks,
    required this.progressPercent,
    required this.isComplete,
    this.filePath,
  });

  factory FileChunkProgress.fromJson(Map<String, dynamic> json) {
    return FileChunkProgress(
      fileHash: json['file_hash'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      downloadedChunks: (json['downloaded_chunks'] as num?)?.toInt() ?? 0,
      totalChunks: (json['total_chunks'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      isComplete: json['is_complete'] as bool? ?? false,
      filePath: json['file_path'] as String?,
    );
  }
}

class RoomInfo {
  final String id;
  final String name;
  final String description;
  final String creatorHash;
  final String creatorNickname;
  final int createdSec;
  final bool isPrivate;
  final List<String> stewards;

  RoomInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorHash,
    required this.creatorNickname,
    required this.createdSec,
    required this.isPrivate,
    required this.stewards,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      creatorHash: json['creator_hash'] as String? ?? '',
      creatorNickname: json['creator_nickname'] as String? ?? 'Community',
      createdSec: (json['created_sec'] as num?)?.toInt() ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
      stewards: (json['stewards'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class StewardVoteInfo {
  final String proposalId;
  final String roomId;
  final String targetHash;
  final String targetNickname;
  final String action;
  final String reasonCategory;
  final String reasonDetails;
  final String proposerHash;
  final String proposerNickname;
  final List<String> votesFor;
  final List<String> votesAgainst;
  final String status;
  final int createdSec;

  StewardVoteInfo({
    required this.proposalId,
    required this.roomId,
    required this.targetHash,
    required this.targetNickname,
    required this.action,
    required this.reasonCategory,
    required this.reasonDetails,
    required this.proposerHash,
    required this.proposerNickname,
    required this.votesFor,
    required this.votesAgainst,
    required this.status,
    required this.createdSec,
  });

  factory StewardVoteInfo.fromJson(Map<String, dynamic> json) {
    return StewardVoteInfo(
      proposalId: json['proposal_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      targetHash: json['target_hash'] as String? ?? '',
      targetNickname: json['target_nickname'] as String? ?? 'Neighbor',
      action: json['action'] as String? ?? 'promote',
      reasonCategory: json['reason_category'] as String? ?? 'Other',
      reasonDetails: json['reason_details'] as String? ?? '',
      proposerHash: json['proposer_hash'] as String? ?? '',
      proposerNickname: json['proposer_nickname'] as String? ?? 'Neighbor',
      votesFor: (json['votes_for'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      votesAgainst: (json['votes_against'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] as String? ?? 'pending',
      createdSec: (json['created_sec'] as num?)?.toInt() ?? 0,
    );
  }
}

class GovernanceEventInfo {
  final String eventId;
  final String roomId;
  final String summary;
  final String reason;
  final int timestampSec;

  GovernanceEventInfo({
    required this.eventId,
    required this.roomId,
    required this.summary,
    required this.reason,
    required this.timestampSec,
  });

  factory GovernanceEventInfo.fromJson(Map<String, dynamic> json) {
    return GovernanceEventInfo(
      eventId: json['event_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? 0,
    );
  }
}

enum AppThemeProfile {
  defaultDark,
  nightVisionRed,
  sunlightHighContrast,
}

class SerialDeviceInfo {
  final String portName;
  final String portType;
  final int? vid;
  final int? pid;
  final String? manufacturer;
  final String? product;

  SerialDeviceInfo({
    required this.portName,
    required this.portType,
    this.vid,
    this.pid,
    this.manufacturer,
    this.product,
  });

  factory SerialDeviceInfo.fromJson(Map<String, dynamic> json) {
    return SerialDeviceInfo(
      portName: json['port_name'] as String? ?? '',
      portType: json['port_type'] as String? ?? 'Standard',
      vid: (json['vid'] as num?)?.toInt(),
      pid: (json['pid'] as num?)?.toInt(),
      manufacturer: json['manufacturer'] as String?,
      product: json['product'] as String?,
    );
  }

  String get displayName {
    if (product != null && product!.isNotEmpty) {
      return '$portName ($product)';
    }
    if (manufacturer != null && manufacturer!.isNotEmpty) {
      return '$portName ($manufacturer)';
    }
    return portName;
  }
}

class LoraRadioStatus {
  final bool isConnected;
  final String portName;
  final int baudRate;
  final int freqHz;
  final int bwHz;
  final int sf;
  final int cr;
  final int txPackets;
  final int rxPackets;
  final int lastRssi;
  final int lastSnr;
  final int lastActivityEpochSec;

  LoraRadioStatus({
    required this.isConnected,
    required this.portName,
    required this.baudRate,
    required this.freqHz,
    required this.bwHz,
    required this.sf,
    required this.cr,
    required this.txPackets,
    required this.rxPackets,
    required this.lastRssi,
    required this.lastSnr,
    required this.lastActivityEpochSec,
  });

  factory LoraRadioStatus.fromJson(Map<String, dynamic> json) {
    return LoraRadioStatus(
      isConnected: json['is_connected'] as bool? ?? false,
      portName: json['port_name'] as String? ?? '',
      baudRate: (json['baud_rate'] as num?)?.toInt() ?? 115200,
      freqHz: (json['freq_hz'] as num?)?.toInt() ?? 915000000,
      bwHz: (json['bw_hz'] as num?)?.toInt() ?? 125000,
      sf: (json['sf'] as num?)?.toInt() ?? 10,
      cr: (json['cr'] as num?)?.toInt() ?? 5,
      txPackets: (json['tx_packets'] as num?)?.toInt() ?? 0,
      rxPackets: (json['rx_packets'] as num?)?.toInt() ?? 0,
      lastRssi: (json['last_rssi'] as num?)?.toInt() ?? -95,
      lastSnr: (json['last_snr'] as num?)?.toInt() ?? 6,
      lastActivityEpochSec: (json['last_activity_epoch_sec'] as num?)?.toInt() ?? 0,
    );
  }

  String get frequencyMhz {
    return (freqHz / 1000000.0).toStringAsFixed(1);
  }

  String get bandwidthKhz {
    return (bwHz / 1000.0).toStringAsFixed(0);
  }
}

class FormFieldDef {
  final String id;
  final String label;
  final String fieldType; // "text", "number", "select", "checkbox", "datetime"
  final bool required;
  final List<String> options;
  final String? defaultValue;

  FormFieldDef({
    required this.id,
    required this.label,
    required this.fieldType,
    required this.required,
    this.options = const [],
    this.defaultValue,
  });

  factory FormFieldDef.fromJson(Map<String, dynamic> json) {
    return FormFieldDef(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      defaultValue: json['default_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'field_type': fieldType,
      'required': required,
      'options': options,
      'default_value': defaultValue,
    };
  }
}

class FormSchema {
  final String id;
  final String title;
  final String category; // "triage", "logistics", "barter", "rollcall", "custom"
  final String description;
  final String authorHash;
  final String authorNickname;
  final List<FormFieldDef> fields;
  final int createdAt;

  FormSchema({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.authorHash,
    required this.authorNickname,
    required this.fields,
    required this.createdAt,
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    return FormSchema(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Community Form',
      category: json['category'] as String? ?? 'custom',
      description: json['description'] as String? ?? '',
      authorHash: json['author_hash'] as String? ?? '',
      authorNickname: json['author_nickname'] as String? ?? 'Neighbor',
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => FormFieldDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'author_hash': authorHash,
      'author_nickname': authorNickname,
      'fields': fields.map((f) => f.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}

class FormEntry {
  final String id;
  final String schemaId;
  final String authorHash;
  final String authorNickname;
  final String dataJson;
  final int timestampSec;
  final String signatureHex;

  FormEntry({
    required this.id,
    required this.schemaId,
    required this.authorHash,
    required this.authorNickname,
    required this.dataJson,
    required this.timestampSec,
    required this.signatureHex,
  });

  factory FormEntry.fromJson(Map<String, dynamic> json) {
    return FormEntry(
      id: json['id'] as String? ?? '',
      schemaId: json['schema_id'] as String? ?? '',
      authorHash: json['author_hash'] as String? ?? '',
      authorNickname: json['author_nickname'] as String? ?? 'Neighbor',
      dataJson: json['data_json'] as String? ?? '{}',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? 0,
      signatureHex: json['signature_hex'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schema_id': schemaId,
      'author_hash': authorHash,
      'author_nickname': authorNickname,
      'data_json': dataJson,
      'timestamp_sec': timestampSec,
      'signature_hex': signatureHex,
    };
  }

  Map<String, dynamic> get parsedData {
    try {
      return jsonDecode(dataJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

const List<String> kStandardTacticalSkills = [
  'Medical / First Aid',
  'HAM Radio Operator',
  'Search & Rescue',
  'Solar & Off-Grid Power',
  'Water Purification',
  'Logistics & Supplies',
  'Carpentry & Shelter',
  'Comms & Security',
  'Fire & Hazard Response',
  'Vehicle / Mechanical Repair',
];

class UserProfile {
  final String destHash;
  final String nickname;
  final String bio;
  final String avatarBase64;
  final String callsign;
  final String contactInfo;
  final String neighborhoodZone;
  final List<String> skills;
  final int updatedAtSec;

  UserProfile({
    required this.destHash,
    required this.nickname,
    this.bio = '',
    this.avatarBase64 = '',
    this.callsign = '',
    this.contactInfo = '',
    this.neighborhoodZone = '',
    this.skills = const [],
    this.updatedAtSec = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var rawSkills = json['skills'];
    List<String> parsedSkills = [];
    if (rawSkills is List) {
      parsedSkills = rawSkills.map((e) => e.toString()).toList();
    } else if (rawSkills is String && rawSkills.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSkills);
        if (decoded is List) {
          parsedSkills = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return UserProfile(
      destHash: json['dest_hash'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Neighbor',
      bio: json['bio'] as String? ?? '',
      avatarBase64: json['avatar_base64'] as String? ?? '',
      callsign: json['callsign'] as String? ?? '',
      contactInfo: json['contact_info'] as String? ?? '',
      neighborhoodZone: json['neighborhood_zone'] as String? ?? '',
      skills: parsedSkills,
      updatedAtSec: (json['updated_at_sec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dest_hash': destHash,
      'nickname': nickname,
      'bio': bio,
      'avatar_base64': avatarBase64,
      'callsign': callsign,
      'contact_info': contactInfo,
      'neighborhood_zone': neighborhoodZone,
      'skills': skills,
      'updated_at_sec': updatedAtSec,
    };
  }

  UserProfile copyWith({
    String? destHash,
    String? nickname,
    String? bio,
    String? avatarBase64,
    String? callsign,
    String? contactInfo,
    String? neighborhoodZone,
    List<String>? skills,
    int? updatedAtSec,
  }) {
    return UserProfile(
      destHash: destHash ?? this.destHash,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      callsign: callsign ?? this.callsign,
      contactInfo: contactInfo ?? this.contactInfo,
      neighborhoodZone: neighborhoodZone ?? this.neighborhoodZone,
      skills: skills ?? this.skills,
      updatedAtSec: updatedAtSec ?? this.updatedAtSec,
    );
  }

  /// Generates a standardized tactical contact URI:
  /// neighbornet://contact?dest=...&nick=...&call=...&zone=...&avatar=...&skills=...&contact=...&ts=...
  String toContactUri() {
    final queryParams = <String, String>{
      'dest': destHash,
      if (nickname.isNotEmpty) 'nick': nickname,
      if (callsign.isNotEmpty) 'call': callsign,
      if (neighborhoodZone.isNotEmpty) 'zone': neighborhoodZone,
      if (bio.isNotEmpty) 'bio': bio,
      if (contactInfo.isNotEmpty) 'contact': contactInfo,
      if (avatarBase64.isNotEmpty) 'avatar': avatarBase64,
      if (skills.isNotEmpty) 'skills': skills.join(','),
      if (updatedAtSec > 0) 'ts': updatedAtSec.toString(),
    };
    final uri = Uri(
      scheme: 'neighbornet',
      host: 'contact',
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// Parses a tactical contact URI or JSON string into a UserProfile.
  static UserProfile? fromContactUri(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Check if JSON format
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        return UserProfile.fromJson(map);
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme == 'neighbornet' && (uri.host == 'contact' || uri.path.contains('contact') || uri.host.isNotEmpty)) {
        final q = uri.queryParameters;
        final dest = q['dest'] ?? (uri.host != 'contact' ? uri.host : '');
        if (dest.isEmpty) return null;

        final skillsRaw = q['skills'] ?? '';
        final skillsList = skillsRaw.isNotEmpty
            ? skillsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : <String>[];

        return UserProfile(
          destHash: dest,
          nickname: q['nick'] ?? 'Neighbor',
          callsign: q['call'] ?? '',
          neighborhoodZone: q['zone'] ?? '',
          bio: q['bio'] ?? '',
          contactInfo: q['contact'] ?? '',
          avatarBase64: q['avatar'] ?? '',
          skills: skillsList,
          updatedAtSec: int.tryParse(q['ts'] ?? '') ?? 0,
        );
      }
    } catch (_) {}

    return null;
  }
}

// --- PUSH-TO-TALK (PTT) TACTICAL WALKIE-TALKIE MODELS ---

class PttChannelInfo {
  final String id;
  final String name;
  final String frequencyLabel;
  final String description;
  final bool isEmergency;

  const PttChannelInfo({
    required this.id,
    required this.name,
    required this.frequencyLabel,
    required this.description,
    this.isEmergency = false,
  });
}

const List<PttChannelInfo> kStandardPttChannels = [
  PttChannelInfo(
    id: 'CH-01',
    name: 'Tac-General',
    frequencyLabel: '462.5625 MHz (Simplex)',
    description: 'Primary community mesh calling & tactical floor channel',
  ),
  PttChannelInfo(
    id: 'CH-02',
    name: 'Logistics & Supplies',
    frequencyLabel: '462.5875 MHz (Simplex)',
    description: 'Resource distribution, transport convoys, and inventory coordination',
  ),
  PttChannelInfo(
    id: 'CH-03',
    name: 'CERT & Medical',
    frequencyLabel: '462.6125 MHz (Simplex)',
    description: 'First-aid triage, search and rescue, and casualty evacuation',
  ),
  PttChannelInfo(
    id: 'CH-09',
    name: 'Emergency Distress Net',
    frequencyLabel: '462.6750 MHz (Priority Net)',
    description: 'Emergency priority broadcast channel with Net Control override',
    isEmergency: true,
  ),
  PttChannelInfo(
    id: 'CH-16',
    name: 'Tactical Recon',
    frequencyLabel: '462.7250 MHz (Simplex)',
    description: 'Perimeter patrol, observation posts, and situational security reports',
  ),
];

class PttVoiceChunk {
  final String sessionId;
  final int sequence;
  final String channel;
  final String senderHash;
  final String senderNickname;
  final String senderCallsign;
  final String audioBase64;
  final bool isFinal;
  final String priority;
  final int timestampSec;

  PttVoiceChunk({
    required this.sessionId,
    required this.sequence,
    required this.channel,
    required this.senderHash,
    required this.senderNickname,
    required this.senderCallsign,
    required this.audioBase64,
    required this.isFinal,
    this.priority = 'normal',
    required this.timestampSec,
  });

  factory PttVoiceChunk.fromJson(Map<String, dynamic> json) {
    return PttVoiceChunk(
      sessionId: json['session_id'] as String? ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String? ?? 'CH-01',
      senderHash: json['sender_hash'] as String? ?? '',
      senderNickname: json['sender_nickname'] as String? ?? 'Neighbor',
      senderCallsign: json['sender_callsign'] as String? ?? '',
      audioBase64: json['audio_base64'] as String? ?? '',
      isFinal: json['is_final'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'normal',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'sequence': sequence,
      'channel': channel,
      'sender_hash': senderHash,
      'sender_nickname': senderNickname,
      'sender_callsign': senderCallsign,
      'audio_base64': audioBase64,
      'is_final': isFinal,
      'priority': priority,
      'timestamp_sec': timestampSec,
    };
  }
}

class PttFloorEvent {
  final String channel;
  final String speakerHash;
  final String speakerNickname;
  final String speakerCallsign;
  final bool isTransmitting;
  final String priority;
  final int timestampSec;

  PttFloorEvent({
    required this.channel,
    required this.speakerHash,
    required this.speakerNickname,
    required this.speakerCallsign,
    required this.isTransmitting,
    this.priority = 'normal',
    required this.timestampSec,
  });

  factory PttFloorEvent.fromJson(Map<String, dynamic> json) {
    return PttFloorEvent(
      channel: json['channel'] as String? ?? 'CH-01',
      speakerHash: json['speaker_hash'] as String? ?? '',
      speakerNickname: json['speaker_nickname'] as String? ?? 'Neighbor',
      speakerCallsign: json['speaker_callsign'] as String? ?? '',
      isTransmitting: json['is_transmitting'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'normal',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel': channel,
      'speaker_hash': speakerHash,
      'speaker_nickname': speakerNickname,
      'speaker_callsign': speakerCallsign,
      'is_transmitting': isTransmitting,
      'priority': priority,
      'timestamp_sec': timestampSec,
    };
  }
}

class PttTransmissionLog {
  final String id;
  final String sessionId;
  final String channel;
  final String senderHash;
  final String senderNickname;
  final String senderCallsign;
  final int durationSec;
  final int chunkCount;
  final String priority;
  final int timestampSec;
  final List<String> audioChunks;

  PttTransmissionLog({
    required this.id,
    required this.sessionId,
    required this.channel,
    required this.senderHash,
    required this.senderNickname,
    required this.senderCallsign,
    required this.durationSec,
    required this.chunkCount,
    this.priority = 'normal',
    required this.timestampSec,
    this.audioChunks = const [],
  });
}

class BarterListing {
  final String id;
  final String listingType; // "offer", "request", "skill"
  final String title;
  final String description;
  final String category; // "fuel", "food_water", "medical", "tools", "shelter", "skills", "comms", "general"
  final String itemCondition; // "new", "good", "fair", "poor", "na"
  final String seeking;
  final String locationHint;
  final String authorHash;
  final String authorNickname;
  final String authorCallsign;
  final String status; // "active", "pending", "completed", "cancelled", "open"
  final int timestampSec;
  final String signatureHex;
  final String? urgency;

  BarterListing({
    required this.id,
    required this.listingType,
    required this.title,
    required this.description,
    required this.category,
    this.itemCondition = 'good',
    required this.seeking,
    required this.locationHint,
    required this.authorHash,
    required this.authorNickname,
    this.authorCallsign = '',
    required this.status,
    required this.timestampSec,
    this.signatureHex = '',
    this.urgency,
  });

  factory BarterListing.fromJson(Map<String, dynamic> json) {
    return BarterListing(
      id: json['id'] as String? ?? '',
      listingType: json['listing_type'] as String? ?? json['listingType'] as String? ?? 'offer',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      itemCondition: json['item_condition'] as String? ?? json['itemCondition'] as String? ?? 'good',
      seeking: json['seeking'] as String? ?? '',
      locationHint: json['location_hint'] as String? ?? json['locationHint'] as String? ?? '',
      authorHash: json['author_hash'] as String? ?? json['authorHash'] as String? ?? '',
      authorNickname: json['author_nickname'] as String? ?? json['authorNickname'] as String? ?? 'Anonymous',
      authorCallsign: json['author_callsign'] as String? ?? json['authorCallsign'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? (json['timestampSec'] as num?)?.toInt() ?? 0,
      signatureHex: json['signature_hex'] as String? ?? json['signatureHex'] as String? ?? '',
      urgency: json['urgency'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_type': listingType,
      'title': title,
      'description': description,
      'category': category,
      'item_condition': itemCondition,
      'seeking': seeking,
      'location_hint': locationHint,
      'author_hash': authorHash,
      'author_nickname': authorNickname,
      'author_callsign': authorCallsign,
      'status': status,
      'timestamp_sec': timestampSec,
      'signature_hex': signatureHex,
      if (urgency != null) 'urgency': urgency,
    };
  }
}

class BarterProposal {
  final String id;
  final String listingId;
  final String proposerHash;
  final String proposerNickname;
  final String proposerCallsign;
  final String offeredItems;
  final String counterMessage;
  final String status; // "proposed", "pending", "accepted", "declined", "completed"
  final int timestampSec;

  BarterProposal({
    required this.id,
    required this.listingId,
    required this.proposerHash,
    required this.proposerNickname,
    this.proposerCallsign = '',
    required this.offeredItems,
    required this.counterMessage,
    required this.status,
    required this.timestampSec,
  });

  factory BarterProposal.fromJson(Map<String, dynamic> json) {
    return BarterProposal(
      id: json['id'] as String? ?? '',
      listingId: json['listing_id'] as String? ?? json['listingId'] as String? ?? '',
      proposerHash: json['proposer_hash'] as String? ?? json['proposerHash'] as String? ?? '',
      proposerNickname: json['proposer_nickname'] as String? ?? json['proposerNickname'] as String? ?? 'Anonymous',
      proposerCallsign: json['proposer_callsign'] as String? ?? json['proposerCallsign'] as String? ?? '',
      offeredItems: json['offered_items'] as String? ?? json['offeredItems'] as String? ?? '',
      counterMessage: json['counter_message'] as String? ?? json['counterMessage'] as String? ?? '',
      status: json['status'] as String? ?? 'proposed',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? (json['timestampSec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'proposer_hash': proposerHash,
      'proposer_nickname': proposerNickname,
      'proposer_callsign': proposerCallsign,
      'offered_items': offeredItems,
      'counter_message': counterMessage,
      'status': status,
      'timestamp_sec': timestampSec,
    };
  }
}

class CommunityVouch {
  final String id;
  final String targetNodeHash;
  final String voucherNodeHash;
  final String voucherNickname;
  final String voucherCallsign;
  final int rating;
  final String reviewComment;
  final int timestampSec;

  CommunityVouch({
    required this.id,
    required this.targetNodeHash,
    required this.voucherNodeHash,
    required this.voucherNickname,
    this.voucherCallsign = '',
    required this.rating,
    required this.reviewComment,
    required this.timestampSec,
  });

  factory CommunityVouch.fromJson(Map<String, dynamic> json) {
    return CommunityVouch(
      id: json['id'] as String? ?? '',
      targetNodeHash: json['target_node_hash'] as String? ?? json['targetNodeHash'] as String? ?? '',
      voucherNodeHash: json['voucher_node_hash'] as String? ?? json['voucherNodeHash'] as String? ?? '',
      voucherNickname: json['voucher_nickname'] as String? ?? json['voucherNickname'] as String? ?? 'Anonymous',
      voucherCallsign: json['voucher_callsign'] as String? ?? json['voucherCallsign'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      reviewComment: json['review_comment'] as String? ?? json['reviewComment'] as String? ?? '',
      timestampSec: (json['timestamp_sec'] as num?)?.toInt() ?? (json['timestampSec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_node_hash': targetNodeHash,
      'voucher_node_hash': voucherNodeHash,
      'voucher_nickname': voucherNickname,
      'voucher_callsign': voucherCallsign,
      'rating': rating,
      'review_comment': reviewComment,
      'timestamp_sec': timestampSec,
    };
  }
}

class WebGatewayStatus {
  final bool isRunning;
  final int port;
  final String localIp;
  final String gatewayUrl;
  final int requestsServed;

  WebGatewayStatus({
    required this.isRunning,
    required this.port,
    required this.localIp,
    required this.gatewayUrl,
    required this.requestsServed,
  });

  factory WebGatewayStatus.fromJson(Map<String, dynamic> json) {
    return WebGatewayStatus(
      isRunning: json['is_running'] as bool? ?? false,
      port: (json['port'] as num?)?.toInt() ?? 8080,
      localIp: json['local_ip'] as String? ?? '127.0.0.1',
      gatewayUrl: json['gateway_url'] as String? ?? '',
      requestsServed: (json['requests_served'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_running': isRunning,
      'port': port,
      'local_ip': localIp,
      'gateway_url': gatewayUrl,
      'requests_served': requestsServed,
    };
  }
}

class DnsServerStatus {
  final bool isRunning;
  final int port;
  final String targetIp;
  final int queriesAnswered;

  DnsServerStatus({
    required this.isRunning,
    required this.port,
    required this.targetIp,
    required this.queriesAnswered,
  });

  factory DnsServerStatus.fromJson(Map<String, dynamic> json) {
    return DnsServerStatus(
      isRunning: json['is_running'] as bool? ?? false,
      port: (json['port'] as num?)?.toInt() ?? 53,
      targetIp: json['target_ip'] as String? ?? '127.0.0.1',
      queriesAnswered: (json['queries_answered'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_running': isRunning,
      'port': port,
      'target_ip': targetIp,
      'queries_answered': queriesAnswered,
    };
  }
}







