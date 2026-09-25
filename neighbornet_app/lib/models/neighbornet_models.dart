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

  ChatMessage({
    required this.id,
    required this.channel,
    required this.senderHash,
    required this.senderNickname,
    required this.content,
    required this.timestampSec,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      channel: json['channel'] ?? 'general',
      senderHash: json['sender_hash'] ?? '',
      senderNickname: json['sender_nickname'] ?? 'Neighbor',
      content: json['content'] ?? '',
      timestampSec: json['timestamp_sec'] ?? 0,
    );
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
}


