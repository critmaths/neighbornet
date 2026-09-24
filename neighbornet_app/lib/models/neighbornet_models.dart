class NodeStatus {
  final String destHash;
  final String nickname;
  final int listenPort;
  final bool isTransport;
  final int peerCount;
  final int bulletinCount;
  final int fileCount;
  final int uptimeSec;

  NodeStatus({
    required this.destHash,
    required this.nickname,
    required this.listenPort,
    required this.isTransport,
    required this.peerCount,
    required this.bulletinCount,
    this.fileCount = 0,
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
