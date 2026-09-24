pub mod kiss;
pub mod lora;

use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString};

use std::fs;
use std::net::{SocketAddr, UdpSocket};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use base64::prelude::*;
use parking_lot::RwLock;
use rand_core::OsRng;
use reticulum_rs::core::identity::{HashIdentity, PrivateIdentity};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const FILE_CHUNK_SIZE: usize = 8192; // 8 KB content-addressed chunks

// --- DATA STRUCTURES ---

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct PeerInfo {
    pub dest_hash: String,
    pub nickname: String,
    pub addr: String,
    pub is_transport: bool,
    pub last_seen_epoch_sec: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct ChatMessage {
    pub id: String,
    pub channel: String,
    pub sender_hash: String,
    pub sender_nickname: String,
    pub content: String,
    pub timestamp_sec: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct BulletinPost {
    pub id: String,
    pub title: String,
    pub body: String,
    pub urgency: String, // "normal", "urgent", "emergency"
    pub author_hash: String,
    pub author_nickname: String,
    pub timestamp_sec: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct SharedFileMeta {
    pub file_hash: String,
    pub filename: String,
    pub file_size: u64,
    pub chunk_count: usize,
    pub chunk_size: usize,
    pub description: String,
    pub author_hash: String,
    pub author_nickname: String,
    pub timestamp_sec: u64,
    pub is_complete: bool,
}

// --- GOVERNANCE & ROOM STRUCTURES ---

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct RoomMeta {
    pub id: String,
    pub name: String,
    pub description: String,
    pub creator_hash: String,
    pub creator_nickname: String,
    pub created_sec: u64,
    pub is_private: bool,
    pub stewards: Vec<String>, // list of destination hashes
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct StewardVote {
    pub proposal_id: String,
    pub room_id: String,
    pub target_hash: String,
    pub target_nickname: String,
    pub action: String, // "promote" or "demote"
    pub reason_category: String, // "Inactivity", "Spam / Disruption", "Misinformation", "Abuse of Power", "Other"
    pub reason_details: String,
    pub proposer_hash: String,
    pub proposer_nickname: String,
    pub votes_for: Vec<String>,
    pub votes_against: Vec<String>,
    pub status: String, // "pending", "passed", "rejected"
    pub created_sec: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct GovernanceEvent {
    pub event_id: String,
    pub room_id: String,
    pub summary: String,
    pub reason: String,
    pub timestamp_sec: u64,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "kind")]
pub enum WireEnvelope {
    Announce {
        dest_hash: String,
        nickname: String,
        is_transport: bool,
        bulletin_count: usize,
        file_count: usize,
        room_count: usize,
    },
    Chat(ChatMessage),
    Bulletin(BulletinPost),
    SyncRequest {
        known_bulletin_ids: Vec<String>,
        known_file_hashes: Vec<String>,
        known_room_ids: Vec<String>,
    },
    SyncResponse {
        bulletins: Vec<BulletinPost>,
        files: Vec<SharedFileMeta>,
        rooms: Vec<RoomMeta>,
    },
    FileAnnounce(SharedFileMeta),
    FileChunkRequest {
        file_hash: String,
        chunk_index: usize,
    },
    FileChunkResponse {
        file_hash: String,
        chunk_index: usize,
        chunk_data_base64: String,
    },
    RoomAnnounce(RoomMeta),
    VoteProposal(StewardVote),
    VoteBallot {
        proposal_id: String,
        voter_hash: String,
        approve: bool,
    },
    GovernanceEventBroadcast(GovernanceEvent),
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NodeStatus {
    pub dest_hash: String,
    pub nickname: String,
    pub listen_port: u16,
    pub is_transport: bool,
    pub peer_count: usize,
    pub bulletin_count: usize,
    pub file_count: usize,
    pub room_count: usize,
    pub uptime_sec: u64,
}

// --- NODE IMPLEMENTATION ---

pub struct NodeInner {
    pub dest_hash_hex: String,
    pub nickname: RwLock<String>,
    pub listen_port: u16,
    pub is_transport: bool,
    pub data_dir: PathBuf,
    pub db: Mutex<Connection>,
    pub peers: RwLock<HashMap<String, PeerInfo>>,
    pub messages: RwLock<Vec<ChatMessage>>,
    pub bulletins: RwLock<HashMap<String, BulletinPost>>,
    pub files: RwLock<HashMap<String, SharedFileMeta>>,
    pub rooms: RwLock<HashMap<String, RoomMeta>>,
    pub proposals: RwLock<HashMap<String, StewardVote>>,
    pub audit_log: RwLock<HashMap<String, Vec<GovernanceEvent>>>,
    pub seen_ids: RwLock<HashSet<String>>,
    pub running: AtomicBool,
    pub start_time: Instant,
    pub socket: UdpSocket,
    pub lora_manager: Arc<lora::LoraManager>,
}


pub struct NeighborNode {
    pub inner: Arc<NodeInner>,
}

fn current_epoch_sec() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn compute_hash(data: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    hex::encode(hasher.finalize())
}

fn load_or_create_identity(data_dir: &Path) -> (PrivateIdentity, String) {
    let key_path = data_dir.join("identity.hex");
    if let Ok(content) = fs::read_to_string(&key_path) {
        let trimmed = content.trim();
        if let Ok(identity) = PrivateIdentity::new_from_hex_string(trimmed) {
            let hash_hex = hex::encode(identity.as_address_hash_slice());
            return (identity, hash_hex);
        }
    }

    let identity = PrivateIdentity::new_from_rand(OsRng);
    let hash_hex = hex::encode(identity.as_address_hash_slice());
    let hex_str = hex::encode(identity.to_private_key_bytes());
    let _ = fs::write(key_path, hex_str);

    (identity, hash_hex)
}

impl NeighborNode {
    pub fn new(data_dir: PathBuf, listen_port: u16, is_transport: bool) -> Result<Self, String> {
        let _ = fs::create_dir_all(&data_dir);
        let _ = fs::create_dir_all(data_dir.join("files").join("meta"));
        let _ = fs::create_dir_all(data_dir.join("files").join("chunks"));
        let _ = fs::create_dir_all(data_dir.join("files").join("completed"));
        let _ = fs::create_dir_all(data_dir.join("rooms"));
        let _ = fs::create_dir_all(data_dir.join("governance"));

        let (_, dest_hash_hex) = load_or_create_identity(&data_dir);

        let bind_addr = format!("0.0.0.0:{}", listen_port);
        let socket = match UdpSocket::bind(&bind_addr) {
            Ok(s) => s,
            Err(_) => {
                UdpSocket::bind("0.0.0.0:0").map_err(|e| format!("Bind failed: {e}"))?
            }
        };

        let _ = socket.set_broadcast(true);
        let _ = socket.set_read_timeout(Some(Duration::from_millis(500)));
        let bound_port = socket.local_addr().map(|a| a.port()).unwrap_or(listen_port);

        let default_nick = format!("Neighbor-{}", &dest_hash_hex[..4]);
        let socket_clone = socket.try_clone().map_err(|e| format!("Clone socket failed: {e}"))?;

        // Load existing saved files
        let mut loaded_files = HashMap::new();
        let meta_dir = data_dir.join("files").join("meta");
        if let Ok(entries) = fs::read_dir(&meta_dir) {
            for entry in entries.flatten() {
                if entry.path().extension().and_then(|e| e.to_str()) == Some("json") {
                    if let Ok(content) = fs::read_to_string(entry.path()) {
                        if let Ok(mut meta) = serde_json::from_str::<SharedFileMeta>(&content) {
                            let comp_path = data_dir
                                .join("files")
                                .join("completed")
                                .join(&meta.file_hash)
                                .join(&meta.filename);
                            meta.is_complete = comp_path.exists();
                            loaded_files.insert(meta.file_hash.clone(), meta);
                        }
                    }
                }
            }
        }

        // Load existing rooms
        let mut loaded_rooms = HashMap::new();
        let rooms_dir = data_dir.join("rooms");
        if let Ok(entries) = fs::read_dir(&rooms_dir) {
            for entry in entries.flatten() {
                if entry.path().extension().and_then(|e| e.to_str()) == Some("json") {
                    if let Ok(content) = fs::read_to_string(entry.path()) {
                        if let Ok(room) = serde_json::from_str::<RoomMeta>(&content) {
                            loaded_rooms.insert(room.id.clone(), room);
                        }
                    }
                }
            }
        }

        let db_path = data_dir.join("neighbornet.db");
        let db = Connection::open(db_path).map_err(|e| format!("Failed to open DB: {}", e))?;
        db.execute_batch(
            "CREATE TABLE IF NOT EXISTS messages (
               id TEXT PRIMARY KEY,
               channel TEXT NOT NULL,
               sender_hash TEXT NOT NULL,
               sender_nickname TEXT NOT NULL,
               content TEXT NOT NULL,
               timestamp_sec INTEGER NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_messages_channel ON messages(channel);
             CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp_sec);
             
             CREATE TABLE IF NOT EXISTS bulletins (
               id TEXT PRIMARY KEY,
               author_hash TEXT NOT NULL,
               author_nickname TEXT NOT NULL,
               title TEXT NOT NULL,
               content TEXT NOT NULL,
               priority TEXT NOT NULL,
               timestamp_sec INTEGER NOT NULL
             );"
        ).map_err(|e| format!("Failed to initialize DB schema: {}", e))?;

        let mut loaded_messages = Vec::new();
        if let Ok(mut stmt) = db.prepare("SELECT id, channel, sender_hash, sender_nickname, content, timestamp_sec FROM messages ORDER BY timestamp_sec ASC") {
            if let Ok(msg_iter) = stmt.query_map([], |row| {
                Ok(ChatMessage {
                    id: row.get(0)?,
                    channel: row.get(1)?,
                    sender_hash: row.get(2)?,
                    sender_nickname: row.get(3)?,
                    content: row.get(4)?,
                    timestamp_sec: row.get(5)?,
                })
            }) {
                for msg in msg_iter.flatten() {
                    loaded_messages.push(msg);
                }
            }
        }

        let mut loaded_bulletins = HashMap::new();
        if let Ok(mut stmt) = db.prepare("SELECT id, author_hash, author_nickname, title, content, priority, timestamp_sec FROM bulletins") {
            if let Ok(bull_iter) = stmt.query_map([], |row| {
                Ok(BulletinPost {
                    id: row.get(0)?,
                    author_hash: row.get(1)?,
                    author_nickname: row.get(2)?,
                    title: row.get(3)?,
                    body: row.get(4)?,
                    urgency: row.get(5)?,
                    timestamp_sec: row.get(6)?,
                })
            }) {
                for bull in bull_iter.flatten() {
                    loaded_bulletins.insert(bull.id.clone(), bull);
                }
            }
        }

        let mut seen_ids = HashSet::new();
        for msg in &loaded_messages { seen_ids.insert(msg.id.clone()); }
        for id in loaded_bulletins.keys() { seen_ids.insert(id.clone()); }

        let lora_mgr = Arc::new(lora::LoraManager::new());

        let inner = Arc::new(NodeInner {
            dest_hash_hex,
            nickname: RwLock::new(default_nick),
            listen_port: bound_port,
            is_transport,
            data_dir: data_dir.clone(),
            db: Mutex::new(db),
            peers: RwLock::new(HashMap::new()),
            messages: RwLock::new(loaded_messages),
            bulletins: RwLock::new(loaded_bulletins),
            files: RwLock::new(loaded_files),
            rooms: RwLock::new(loaded_rooms),
            proposals: RwLock::new(HashMap::new()),
            audit_log: RwLock::new(HashMap::new()),
            seen_ids: RwLock::new(seen_ids),
            running: AtomicBool::new(true),
            start_time: Instant::now(),
            socket: socket_clone,
            lora_manager: lora_mgr,
        });

        // Set LoRa packet reception callback
        let inner_rx = inner.clone();
        let socket_lora = socket.try_clone().unwrap();
        inner.lora_manager.set_packet_callback(Arc::new(move |payload: Vec<u8>| {
            if let Ok(envelope) = serde_json::from_slice::<WireEnvelope>(&payload) {
                let fake_src = SocketAddr::from(([127, 0, 0, 1], 42424));
                handle_envelope(&inner_rx, &socket_lora, envelope, fake_src);
            }
        }));

        start_network_threads(inner.clone(), socket);

        Ok(Self { inner })
    }


    pub fn stop(&self) {
        self.inner.running.store(false, Ordering::SeqCst);
    }

    pub fn get_status(&self) -> NodeStatus {
        NodeStatus {
            dest_hash: self.inner.dest_hash_hex.clone(),
            nickname: self.inner.nickname.read().clone(),
            listen_port: self.inner.listen_port,
            is_transport: self.inner.is_transport,
            peer_count: self.inner.peers.read().len(),
            bulletin_count: self.inner.bulletins.read().len(),
            file_count: self.inner.files.read().len(),
            room_count: self.inner.rooms.read().len(),
            uptime_sec: self.inner.start_time.elapsed().as_secs(),
        }
    }

    pub fn set_nickname(&self, name: String) {
        *self.inner.nickname.write() = name;
    }

    pub fn post_bulletin(&self, title: String, body: String, urgency: String) -> String {
        let timestamp = current_epoch_sec();
        let raw_id = format!("{}:{}:{}:{}", self.inner.dest_hash_hex, title, body, timestamp);
        let id = compute_hash(&raw_id);

        let post = BulletinPost {
            id: id.clone(),
            title,
            body,
            urgency,
            author_hash: self.inner.dest_hash_hex.clone(),
            author_nickname: self.inner.nickname.read().clone(),
            timestamp_sec: timestamp,
        };

        self.inner.seen_ids.write().insert(id.clone());
        self.inner.bulletins.write().insert(id.clone(), post.clone());

        if let Ok(db) = self.inner.db.lock() {
            let _ = db.execute(
                "INSERT OR IGNORE INTO bulletins (id, author_hash, author_nickname, title, content, priority, timestamp_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                rusqlite::params![
                    post.id,
                    post.author_hash,
                    post.author_nickname,
                    post.title,
                    post.body,
                    post.urgency,
                    post.timestamp_sec
                ]
            );
        }

        let envelope = WireEnvelope::Bulletin(post);
        self.broadcast_envelope(&envelope);
        id
    }

    pub fn send_chat(&self, channel: String, content: String) -> String {
        let timestamp = current_epoch_sec();
        let raw_id = format!("{}:{}:{}:{}", self.inner.dest_hash_hex, channel, content, timestamp);
        let id = compute_hash(&raw_id);

        let chat = ChatMessage {
            id: id.clone(),
            channel,
            sender_hash: self.inner.dest_hash_hex.clone(),
            sender_nickname: self.inner.nickname.read().clone(),
            content,
            timestamp_sec: timestamp,
        };

        self.inner.seen_ids.write().insert(id.clone());
        self.inner.messages.write().push(chat.clone());

        if let Ok(db) = self.inner.db.lock() {
            let _ = db.execute(
                "INSERT OR IGNORE INTO messages (id, channel, sender_hash, sender_nickname, content, timestamp_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                rusqlite::params![
                    chat.id,
                    chat.channel,
                    chat.sender_hash,
                    chat.sender_nickname,
                    chat.content,
                    chat.timestamp_sec
                ]
            );
        }

        let envelope = WireEnvelope::Chat(chat);
        self.broadcast_envelope(&envelope);
        id
    }

    pub fn get_bulletins(&self) -> Vec<BulletinPost> {
        let mut posts = Vec::new();
        if let Ok(db) = self.inner.db.lock() {
            if let Ok(mut stmt) = db.prepare("SELECT id, author_hash, author_nickname, title, content, priority, timestamp_sec FROM bulletins ORDER BY timestamp_sec DESC") {
                if let Ok(bull_iter) = stmt.query_map([], |row| {
                    Ok(BulletinPost {
                        id: row.get(0)?,
                        author_hash: row.get(1)?,
                        author_nickname: row.get(2)?,
                        title: row.get(3)?,
                        body: row.get(4)?,
                        urgency: row.get(5)?,
                        timestamp_sec: row.get(6)?,
                    })
                }) {
                    for bull in bull_iter.flatten() {
                        posts.push(bull);
                    }
                }
            }
        }
        posts
    }

    pub fn get_chat_history(&self, channel: &str) -> Vec<ChatMessage> {
        let mut msgs = Vec::new();
        if let Ok(db) = self.inner.db.lock() {
            if let Ok(mut stmt) = db.prepare("SELECT id, channel, sender_hash, sender_nickname, content, timestamp_sec FROM messages WHERE channel = ?1 ORDER BY timestamp_sec ASC") {
                if let Ok(msg_iter) = stmt.query_map(rusqlite::params![channel], |row| {
                    Ok(ChatMessage {
                        id: row.get(0)?,
                        channel: row.get(1)?,
                        sender_hash: row.get(2)?,
                        sender_nickname: row.get(3)?,
                        content: row.get(4)?,
                        timestamp_sec: row.get(5)?,
                    })
                }) {
                    for msg in msg_iter.flatten() {
                        msgs.push(msg);
                    }
                }
            }
        }
        msgs
    }

    pub fn get_peers(&self) -> Vec<PeerInfo> {
        self.inner.peers.read().values().cloned().collect()
    }

    pub fn connect_peer(&self, addr: SocketAddr) {
        let b_count = self.inner.bulletins.read().len();
        let f_count = self.inner.files.read().len();
        let r_count = self.inner.rooms.read().len();
        let announce = WireEnvelope::Announce {
            dest_hash: self.inner.dest_hash_hex.clone(),
            nickname: self.inner.nickname.read().clone(),
            is_transport: self.inner.is_transport,
            bulletin_count: b_count,
            file_count: f_count,
            room_count: r_count,
        };
        if let Ok(payload) = serde_json::to_string(&announce) {
            let _ = self.inner.socket.send_to(payload.as_bytes(), addr);
        }
    }

    pub fn broadcast_envelope(&self, envelope: &WireEnvelope) {
        if let Ok(json) = serde_json::to_string(envelope) {
            let _ = self.inner.socket.send_to(json.as_bytes(), "255.255.255.255:42424");
            let _ = self.inner.socket.send_to(json.as_bytes(), "127.0.0.1:42424");
            let peer_addrs: Vec<String> = self.inner.peers.read().values().map(|p| p.addr.clone()).collect();
            for addr in peer_addrs {
                if let Ok(dest) = addr.parse::<SocketAddr>() {
                    let _ = self.inner.socket.send_to(json.as_bytes(), dest);
                }
            }
            let _ = self.inner.lora_manager.send_packet(json.as_bytes());
        }
    }


    // --- DECENTRALIZED FILE SHARING SUBSYSTEM ---

    pub fn publish_file(&self, src_path: &Path, description: String) -> Result<String, String> {
        if !src_path.exists() {
            return Err("File not found on local filesystem".to_string());
        }

        let file_bytes = fs::read(src_path).map_err(|e| format!("Failed to read file: {e}"))?;
        let file_size = file_bytes.len() as u64;

        let mut hasher = Sha256::new();
        hasher.update(&file_bytes);
        let file_hash = hex::encode(hasher.finalize());

        let filename = src_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("document")
            .to_string();

        let chunk_count = if file_bytes.is_empty() {
            1
        } else {
            file_bytes.len().div_ceil(FILE_CHUNK_SIZE)
        };

        let comp_dir = self.inner.data_dir.join("files").join("completed").join(&file_hash);
        let _ = fs::create_dir_all(&comp_dir);
        let comp_path = comp_dir.join(&filename);
        let _ = fs::write(&comp_path, &file_bytes);

        let chunk_dir = self.inner.data_dir.join("files").join("chunks").join(&file_hash);
        let _ = fs::create_dir_all(&chunk_dir);
        if file_bytes.is_empty() {
            let _ = fs::write(chunk_dir.join("0"), b"");
        } else {
            for (idx, chunk) in file_bytes.chunks(FILE_CHUNK_SIZE).enumerate() {
                let _ = fs::write(chunk_dir.join(idx.to_string()), chunk);
            }
        }

        let meta = SharedFileMeta {
            file_hash: file_hash.clone(),
            filename,
            file_size,
            chunk_count,
            chunk_size: FILE_CHUNK_SIZE,
            description,
            author_hash: self.inner.dest_hash_hex.clone(),
            author_nickname: self.inner.nickname.read().clone(),
            timestamp_sec: current_epoch_sec(),
            is_complete: true,
        };

        let meta_dir = self.inner.data_dir.join("files").join("meta");
        let _ = fs::create_dir_all(&meta_dir);
        if let Ok(json) = serde_json::to_string_pretty(&meta) {
            let _ = fs::write(meta_dir.join(format!("{}.json", file_hash)), json);
        }

        self.inner.files.write().insert(file_hash.clone(), meta.clone());

        let envelope = WireEnvelope::FileAnnounce(meta);
        self.broadcast_envelope(&envelope);

        Ok(file_hash)
    }

    pub fn get_shared_files(&self) -> Vec<SharedFileMeta> {
        let mut list: Vec<SharedFileMeta> = self.inner.files.read().values().cloned().collect();
        list.sort_by_key(|a| std::cmp::Reverse(a.timestamp_sec));
        list
    }

    pub fn request_file(&self, file_hash: &str) -> bool {
        let files_guard = self.inner.files.read();
        let meta = match files_guard.get(file_hash) {
            Some(m) => m.clone(),
            None => return false,
        };
        drop(files_guard);

        if meta.is_complete {
            return true;
        }

        let chunk_dir = self.inner.data_dir.join("files").join("chunks").join(file_hash);
        for idx in 0..meta.chunk_count {
            let chunk_path = chunk_dir.join(idx.to_string());
            if !chunk_path.exists() {
                let req = WireEnvelope::FileChunkRequest {
                    file_hash: file_hash.to_string(),
                    chunk_index: idx,
                };
                self.broadcast_envelope(&req);
                return true;
            }
        }

        false
    }

    pub fn get_completed_file_path(&self, file_hash: &str) -> Option<PathBuf> {
        let files_guard = self.inner.files.read();
        let meta = files_guard.get(file_hash)?;
        if !meta.is_complete {
            return None;
        }

        let comp_path = self
            .inner
            .data_dir
            .join("files")
            .join("completed")
            .join(file_hash)
            .join(&meta.filename);

        if comp_path.exists() {
            Some(comp_path)
        } else {
            None
        }
    }

    // --- DYNAMIC ROOMS & DEMOCRATIC GOVERNANCE SUBSYSTEM ---

    pub fn create_room(&self, name: String, description: String, is_private: bool) -> RoomMeta {
        let timestamp = current_epoch_sec();
        let raw_id = format!("{}:{}:{}", self.inner.dest_hash_hex, name, timestamp);
        let id = format!("room_{}", &compute_hash(&raw_id)[..16]);

        let room = RoomMeta {
            id: id.clone(),
            name,
            description,
            creator_hash: self.inner.dest_hash_hex.clone(),
            creator_nickname: self.inner.nickname.read().clone(),
            created_sec: timestamp,
            is_private,
            stewards: vec![self.inner.dest_hash_hex.clone()], // Creator is genesis steward
        };

        // Persist room
        let rooms_dir = self.inner.data_dir.join("rooms");
        let _ = fs::create_dir_all(&rooms_dir);
        if let Ok(json) = serde_json::to_string_pretty(&room) {
            let _ = fs::write(rooms_dir.join(format!("{}.json", id)), json);
        }

        self.inner.rooms.write().insert(id.clone(), room.clone());

        // Broadcast room creation
        let envelope = WireEnvelope::RoomAnnounce(room.clone());
        self.broadcast_envelope(&envelope);

        room
    }

    pub fn get_rooms(&self) -> Vec<RoomMeta> {
        let mut list: Vec<RoomMeta> = self.inner.rooms.read().values().cloned().collect();
        list.sort_by_key(|a| a.created_sec);
        list
    }

    pub fn propose_steward_vote(
        &self,
        room_id: String,
        target_hash: String,
        target_nickname: String,
        action: String,
        reason_category: String,
        reason_details: String,
    ) -> Result<String, String> {
        if !self.inner.rooms.read().contains_key(&room_id) {
            return Err("Room does not exist".to_string());
        }

        let timestamp = current_epoch_sec();
        let raw_id = format!("{}:{}:{}:{}:{}", room_id, target_hash, action, self.inner.dest_hash_hex, timestamp);
        let proposal_id = format!("prop_{}", &compute_hash(&raw_id)[..16]);

        let vote = StewardVote {
            proposal_id: proposal_id.clone(),
            room_id: room_id.clone(),
            target_hash,
            target_nickname,
            action,
            reason_category,
            reason_details,
            proposer_hash: self.inner.dest_hash_hex.clone(),
            proposer_nickname: self.inner.nickname.read().clone(),
            votes_for: vec![self.inner.dest_hash_hex.clone()], // Proposer votes FOR automatically
            votes_against: Vec::new(),
            status: "pending".to_string(),
            created_sec: timestamp,
        };

        self.inner.proposals.write().insert(proposal_id.clone(), vote.clone());

        // Evaluate immediately in case of single-member room genesis
        self.evaluate_vote_quorum(&proposal_id);

        let envelope = WireEnvelope::VoteProposal(vote);
        self.broadcast_envelope(&envelope);

        Ok(proposal_id)
    }

    pub fn cast_vote(&self, proposal_id: &str, approve: bool) -> bool {
        let my_hash = self.inner.dest_hash_hex.clone();
        let mut proposals = self.inner.proposals.write();
        let vote = match proposals.get_mut(proposal_id) {
            Some(v) => v,
            None => return false,
        };

        if vote.status != "pending" {
            return false;
        }

        // Avoid double voting
        vote.votes_for.retain(|h| h != &my_hash);
        vote.votes_against.retain(|h| h != &my_hash);

        if approve {
            vote.votes_for.push(my_hash.clone());
        } else {
            vote.votes_against.push(my_hash.clone());
        }

        let envelope = WireEnvelope::VoteBallot {
            proposal_id: proposal_id.to_string(),
            voter_hash: my_hash,
            approve,
        };
        drop(proposals);

        self.broadcast_envelope(&envelope);
        self.evaluate_vote_quorum(proposal_id);
        true
    }

    fn evaluate_vote_quorum(&self, proposal_id: &str) {
        let mut proposals = self.inner.proposals.write();
        let vote = match proposals.get_mut(proposal_id) {
            Some(v) => v,
            None => return,
        };

        if vote.status != "pending" {
            return;
        }

        // Active community participants = connected peers + self
        let total_nodes = self.inner.peers.read().len() + 1;
        let required_for_majority = if total_nodes <= 1 {
            1
        } else if total_nodes == 2 {
            2 // Unanimous consensus for 2 people
        } else {
            (total_nodes / 2) + 1 // Democratic majority
        };

        if vote.votes_for.len() >= required_for_majority {
            vote.status = "passed".to_string();

            // Execute promotion / demotion on Room
            let mut rooms = self.inner.rooms.write();
            if let Some(room) = rooms.get_mut(&vote.room_id) {
                if vote.action == "promote" {
                    if !room.stewards.contains(&vote.target_hash) {
                        room.stewards.push(vote.target_hash.clone());
                    }
                } else if vote.action == "demote" {
                    room.stewards.retain(|h| h != &vote.target_hash);
                }

                // Persist updated room
                let rooms_dir = self.inner.data_dir.join("rooms");
                if let Ok(json) = serde_json::to_string_pretty(&room) {
                    let _ = fs::write(rooms_dir.join(format!("{}.json", room.id)), json);
                }
            }

            // Create immutable Governance Audit Log Event
            let event = GovernanceEvent {
                event_id: format!("event_{}", &compute_hash(&format!("{}:{}", vote.proposal_id, current_epoch_sec()))[..16]),
                room_id: vote.room_id.clone(),
                summary: format!(
                    "Steward {} was {} by democratic community vote ({} in favor)",
                    vote.target_nickname,
                    if vote.action == "promote" { "promoted" } else { "demoted" },
                    vote.votes_for.len()
                ),
                reason: format!("{}: {}", vote.reason_category, vote.reason_details),
                timestamp_sec: current_epoch_sec(),
            };

            let mut audit_log = self.inner.audit_log.write();
            audit_log.entry(vote.room_id.clone()).or_default().push(event.clone());

            let gov_env = WireEnvelope::GovernanceEventBroadcast(event);
            drop(audit_log);
            drop(rooms);
            drop(proposals);

            self.broadcast_envelope(&gov_env);
        } else if vote.votes_against.len() > total_nodes.saturating_sub(required_for_majority) {
            vote.status = "rejected".to_string();
        }
    }

    pub fn get_proposals(&self, room_id: &str) -> Vec<StewardVote> {
        self.inner
            .proposals
            .read()
            .values()
            .filter(|v| v.room_id == room_id)
            .cloned()
            .collect()
    }

    pub fn get_audit_log(&self, room_id: &str) -> Vec<GovernanceEvent> {
        self.inner
            .audit_log
            .read()
            .get(room_id)
            .cloned()
            .unwrap_or_default()
    }

    /// Emergency Duress / Panic Wipe:
    /// Securely shreds local cryptographic identity, drops and vacuums SQLite databases,
    /// removes room and file caches, and wipes all in-memory message history.
    pub fn panic_wipe(&self) -> Result<(), String> {
        // 1. Wipe in-memory state
        self.inner.peers.write().clear();
        self.inner.messages.write().clear();
        self.inner.bulletins.write().clear();
        self.inner.files.write().clear();
        self.inner.rooms.write().clear();
        self.inner.proposals.write().clear();
        self.inner.audit_log.write().clear();
        self.inner.seen_ids.write().clear();

        // 2. Drop and securely reset SQLite tables
        if let Ok(conn) = self.inner.db.lock() {
            let _ = conn.execute("DROP TABLE IF EXISTS messages", []);
            let _ = conn.execute("DROP TABLE IF EXISTS bulletins", []);
            let _ = conn.execute("VACUUM", []);

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    channel TEXT NOT NULL,
                    sender_hash TEXT NOT NULL,
                    sender_nickname TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp_sec INTEGER NOT NULL
                )",
                [],
            );
            let _ = conn.execute("CREATE INDEX IF NOT EXISTS idx_messages_channel ON messages(channel)", []);
            let _ = conn.execute("CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp_sec)", []);

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS bulletins (
                    id TEXT PRIMARY KEY,
                    author_hash TEXT NOT NULL,
                    author_nickname TEXT NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    priority TEXT NOT NULL,
                    timestamp_sec INTEGER NOT NULL
                )",
                [],
            );
        }

        // 3. Cryptographically shred and remove identity.hex
        let identity_path = self.inner.data_dir.join("identity.hex");
        if identity_path.exists() {
            if let Ok(meta) = fs::metadata(&identity_path) {
                let len = meta.len() as usize;
                let zeroes = vec![0u8; len.max(64)];
                let _ = fs::write(&identity_path, &zeroes);
            }
            let _ = fs::remove_file(&identity_path);
        }

        // 4. Remove cached room metadata and file chunks
        let rooms_dir = self.inner.data_dir.join("rooms");
        if rooms_dir.exists() {
            let _ = fs::remove_dir_all(&rooms_dir);
        }

        let files_dir = self.inner.data_dir.join("files");
        if files_dir.exists() {
            let _ = fs::remove_dir_all(&files_dir);
        }

        // 5. Generate fresh anonymous nickname
        let mut rng = OsRng;
        let random_suffix: String = (0..4)
            .map(|_| format!("{:x}", rand_core::RngCore::next_u32(&mut rng) % 16))
            .collect();
        *self.inner.nickname.write() = format!("Neighbor-{}", random_suffix);

        Ok(())
    }

    /// Export the node's cryptographic identity as a 48-word BIP-39 mnemonic seed phrase.
    pub fn export_identity_mnemonic(&self) -> Result<String, String> {
        let key_path = self.inner.data_dir.join("identity.hex");
        let content = fs::read_to_string(&key_path).map_err(|e| format!("Failed to read identity file: {e}"))?;
        let trimmed = content.trim();
        let priv_bytes = hex::decode(trimmed).map_err(|e| format!("Invalid hex identity: {e}"))?;
        if priv_bytes.len() < 64 {
            return Err("Identity private key bytes invalid length".to_string());
        }
        let part1 = &priv_bytes[..32];
        let part2 = &priv_bytes[32..64];
        let m1 = bip39::Mnemonic::from_entropy(part1).map_err(|e| format!("{e}"))?;
        let m2 = bip39::Mnemonic::from_entropy(part2).map_err(|e| format!("{e}"))?;
        Ok(format!("{} {}", m1, m2))
    }

    /// Restore or import a cryptographic identity from a BIP-39 mnemonic phrase or raw hex string.
    /// Writes the new identity to identity.hex on disk.
    pub fn restore_identity(&self, phrase_or_hex: &str) -> Result<String, String> {
        let trimmed = phrase_or_hex.trim();
        let bytes = if trimmed.contains(' ') {
            // Mnemonic words
            let words: Vec<&str> = trimmed.split_whitespace().collect();
            if words.len() == 48 {
                let w1 = words[..24].join(" ");
                let w2 = words[24..].join(" ");
                let m1 = bip39::Mnemonic::parse_normalized(&w1).map_err(|e| format!("Invalid phrase part 1: {e}"))?;
                let m2 = bip39::Mnemonic::parse_normalized(&w2).map_err(|e| format!("Invalid phrase part 2: {e}"))?;
                let mut b = Vec::with_capacity(64);
                b.extend_from_slice(&m1.to_entropy());
                b.extend_from_slice(&m2.to_entropy());
                b
            } else if words.len() == 24 {
                let m = bip39::Mnemonic::parse_normalized(trimmed).map_err(|e| format!("Invalid 24-word phrase: {e}"))?;
                let mut b = Vec::with_capacity(64);
                b.extend_from_slice(&m.to_entropy());
                b.extend_from_slice(&m.to_entropy());
                b
            } else {
                return Err(format!("Expected 48 BIP-39 words or 128-char hex string, got {} words", words.len()));
            }
        } else {
            // Raw hex string
            hex::decode(trimmed).map_err(|e| format!("Invalid hex string: {e}"))?
        };

        let hex_str = hex::encode(&bytes);
        let identity = PrivateIdentity::new_from_hex_string(&hex_str)
            .map_err(|e| format!("Invalid identity key bytes: {e:?}"))?;

        let hash_hex = hex::encode(identity.as_address_hash_slice());

        // Save to identity.hex
        let key_path = self.inner.data_dir.join("identity.hex");
        fs::write(&key_path, &hex_str).map_err(|e| format!("Failed to write identity file: {e}"))?;

        Ok(hash_hex)
    }
}

fn start_network_threads(inner: Arc<NodeInner>, socket: UdpSocket) {
    let socket_send = match socket.try_clone() {
        Ok(s) => s,
        Err(_) => return,
    };

    // Receiver Thread
    let inner_rx = inner.clone();
    thread::spawn(move || {
        let mut buf = [0u8; 65535];
        while inner_rx.running.load(Ordering::Relaxed) {
            match socket.recv_from(&mut buf) {
                Ok((size, src)) => {
                    if let Ok(text) = std::str::from_utf8(&buf[..size]) {
                        if let Ok(envelope) = serde_json::from_str::<WireEnvelope>(text) {
                            handle_envelope(&inner_rx, &socket, envelope, src);
                        }
                    }
                }
                Err(_) => {
                    thread::sleep(Duration::from_millis(50));
                }
            }
        }
    });

    // Periodic Announce & Sync Thread
    let inner_tx = inner.clone();
    thread::spawn(move || {
        let broadcast_addrs = vec![
            SocketAddr::from(([255, 255, 255, 255], 42424)),
            SocketAddr::from(([127, 0, 0, 1], 42424)),
        ];

        while inner_tx.running.load(Ordering::Relaxed) {
            let now = current_epoch_sec();
            {
                let mut peers = inner_tx.peers.write();
                peers.retain(|_, p| now.saturating_sub(p.last_seen_epoch_sec) < 30);
            }

            let b_count = inner_tx.bulletins.read().len();
            let f_count = inner_tx.files.read().len();
            let r_count = inner_tx.rooms.read().len();
            let announce = WireEnvelope::Announce {
                dest_hash: inner_tx.dest_hash_hex.clone(),
                nickname: inner_tx.nickname.read().clone(),
                is_transport: inner_tx.is_transport,
                bulletin_count: b_count,
                file_count: f_count,
                room_count: r_count,
            };

            if let Ok(payload) = serde_json::to_string(&announce) {
                for &addr in &broadcast_addrs {
                    let _ = socket_send.send_to(payload.as_bytes(), addr);
                }
                let peer_addrs: Vec<String> = inner_tx.peers.read().values().map(|p| p.addr.clone()).collect();
                for addr_str in peer_addrs {
                    if let Ok(dest) = addr_str.parse::<SocketAddr>() {
                        let _ = socket_send.send_to(payload.as_bytes(), dest);
                    }
                }
            }

            thread::sleep(Duration::from_millis(1500));
        }
    });
}

fn handle_envelope(inner: &Arc<NodeInner>, socket: &UdpSocket, envelope: WireEnvelope, src: SocketAddr) {
    match envelope {
        WireEnvelope::Announce {
            dest_hash,
            nickname,
            is_transport,
            bulletin_count,
            file_count,
            room_count,
        } => {
            if dest_hash == inner.dest_hash_hex {
                return;
            }

            let mut peers = inner.peers.write();
            let is_new = !peers.contains_key(&dest_hash);
            peers.insert(
                dest_hash.clone(),
                PeerInfo {
                    dest_hash: dest_hash.clone(),
                    nickname,
                    addr: src.to_string(),
                    is_transport,
                    last_seen_epoch_sec: current_epoch_sec(),
                },
            );

            // Respond immediately if newly discovered peer
            if is_new {
                let my_announce = WireEnvelope::Announce {
                    dest_hash: inner.dest_hash_hex.clone(),
                    nickname: inner.nickname.read().clone(),
                    is_transport: inner.is_transport,
                    bulletin_count: inner.bulletins.read().len(),
                    file_count: inner.files.read().len(),
                    room_count: inner.rooms.read().len(),
                };
                if let Ok(json) = serde_json::to_string(&my_announce) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }

            // Sync missing bulletins, file manifests, and rooms
            let my_b_count = inner.bulletins.read().len();
            let my_f_count = inner.files.read().len();
            let my_r_count = inner.rooms.read().len();
            if is_new || bulletin_count > my_b_count || file_count > my_f_count || room_count > my_r_count {
                let known_b_ids: Vec<String> = inner.bulletins.read().keys().cloned().collect();
                let known_f_hashes: Vec<String> = inner.files.read().keys().cloned().collect();
                let known_r_ids: Vec<String> = inner.rooms.read().keys().cloned().collect();
                let sync_req = WireEnvelope::SyncRequest {
                    known_bulletin_ids: known_b_ids,
                    known_file_hashes: known_f_hashes,
                    known_room_ids: known_r_ids,
                };
                if let Ok(json) = serde_json::to_string(&sync_req) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::Chat(msg) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(msg.id.clone()) {
                let mut messages = inner.messages.write();
                messages.push(msg.clone());
                
                if let Ok(db) = inner.db.lock() {
                    let _ = db.execute(
                        "INSERT OR IGNORE INTO messages (id, channel, sender_hash, sender_nickname, content, timestamp_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                        rusqlite::params![
                            msg.id,
                            msg.channel,
                            msg.sender_hash,
                            msg.sender_nickname,
                            msg.content,
                            msg.timestamp_sec
                        ]
                    );
                }
            }
        }
        WireEnvelope::Bulletin(post) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(post.id.clone()) {
                let mut bulletins = inner.bulletins.write();
                bulletins.insert(post.id.clone(), post.clone());
                
                if let Ok(db) = inner.db.lock() {
                    let _ = db.execute(
                        "INSERT OR IGNORE INTO bulletins (id, author_hash, author_nickname, title, content, priority, timestamp_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                        rusqlite::params![
                            post.id,
                            post.author_hash,
                            post.author_nickname,
                            post.title,
                            post.body,
                            post.urgency,
                            post.timestamp_sec
                        ]
                    );
                }
            }
        }
        WireEnvelope::SyncRequest {
            known_bulletin_ids,
            known_file_hashes,
            known_room_ids,
        } => {
            let known_b_set: HashSet<String> = known_bulletin_ids.into_iter().collect();
            let missing_bulletins: Vec<BulletinPost> = inner
                .bulletins
                .read()
                .values()
                .filter(|b| !known_b_set.contains(&b.id))
                .cloned()
                .collect();

            let known_f_set: HashSet<String> = known_file_hashes.into_iter().collect();
            let missing_files: Vec<SharedFileMeta> = inner
                .files
                .read()
                .values()
                .filter(|f| !known_f_set.contains(&f.file_hash))
                .cloned()
                .collect();

            let known_r_set: HashSet<String> = known_room_ids.into_iter().collect();
            let missing_rooms: Vec<RoomMeta> = inner
                .rooms
                .read()
                .values()
                .filter(|r| !known_r_set.contains(&r.id))
                .cloned()
                .collect();

            if !missing_bulletins.is_empty() || !missing_files.is_empty() || !missing_rooms.is_empty() {
                let resp = WireEnvelope::SyncResponse {
                    bulletins: missing_bulletins,
                    files: missing_files,
                    rooms: missing_rooms,
                };
                if let Ok(json) = serde_json::to_string(&resp) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::SyncResponse { bulletins, files, rooms } => {
            let mut seen = inner.seen_ids.write();
            let mut stored_b = inner.bulletins.write();
            for b in bulletins {
                if seen.insert(b.id.clone()) {
                    stored_b.insert(b.id.clone(), b.clone());
                    
                    if let Ok(db) = inner.db.lock() {
                        let _ = db.execute(
                            "INSERT OR IGNORE INTO bulletins (id, author_hash, author_nickname, title, content, priority, timestamp_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                            rusqlite::params![
                                b.id,
                                b.author_hash,
                                b.author_nickname,
                                b.title,
                                b.body,
                                b.urgency,
                                b.timestamp_sec
                            ]
                        );
                    }
                }
            }

            let mut stored_f = inner.files.write();
            for mut f in files {
                if !stored_f.contains_key(&f.file_hash) {
                    let comp_path = inner
                        .data_dir
                        .join("files")
                        .join("completed")
                        .join(&f.file_hash)
                        .join(&f.filename);
                    f.is_complete = comp_path.exists();

                    let meta_dir = inner.data_dir.join("files").join("meta");
                    let _ = fs::create_dir_all(&meta_dir);
                    if let Ok(json) = serde_json::to_string_pretty(&f) {
                        let _ = fs::write(meta_dir.join(format!("{}.json", f.file_hash)), json);
                    }

                    stored_f.insert(f.file_hash.clone(), f);
                }
            }

            let mut stored_r = inner.rooms.write();
            for r in rooms {
                if !stored_r.contains_key(&r.id) {
                    let rooms_dir = inner.data_dir.join("rooms");
                    let _ = fs::create_dir_all(&rooms_dir);
                    if let Ok(json) = serde_json::to_string_pretty(&r) {
                        let _ = fs::write(rooms_dir.join(format!("{}.json", r.id)), json);
                    }
                    stored_r.insert(r.id.clone(), r);
                }
            }
        }
        WireEnvelope::FileAnnounce(mut meta) => {
            let mut files = inner.files.write();
            if !files.contains_key(&meta.file_hash) {
                let comp_path = inner
                    .data_dir
                    .join("files")
                    .join("completed")
                    .join(&meta.file_hash)
                    .join(&meta.filename);
                meta.is_complete = comp_path.exists();

                let meta_dir = inner.data_dir.join("files").join("meta");
                let _ = fs::create_dir_all(&meta_dir);
                if let Ok(json) = serde_json::to_string_pretty(&meta) {
                    let _ = fs::write(meta_dir.join(format!("{}.json", meta.file_hash)), json);
                }

                files.insert(meta.file_hash.clone(), meta);
            }
        }
        WireEnvelope::FileChunkRequest { file_hash, chunk_index } => {
            let chunk_path = inner
                .data_dir
                .join("files")
                .join("chunks")
                .join(&file_hash)
                .join(chunk_index.to_string());

            if let Ok(chunk_bytes) = fs::read(&chunk_path) {
                let b64 = BASE64_STANDARD.encode(&chunk_bytes);
                let resp = WireEnvelope::FileChunkResponse {
                    file_hash,
                    chunk_index,
                    chunk_data_base64: b64,
                };
                if let Ok(json) = serde_json::to_string(&resp) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::FileChunkResponse {
            file_hash,
            chunk_index,
            chunk_data_base64,
        } => {
            if let Ok(data) = BASE64_STANDARD.decode(&chunk_data_base64) {
                let chunk_dir = inner.data_dir.join("files").join("chunks").join(&file_hash);
                let _ = fs::create_dir_all(&chunk_dir);
                let chunk_path = chunk_dir.join(chunk_index.to_string());
                let _ = fs::write(chunk_path, &data);

                let meta_opt = inner.files.read().get(&file_hash).cloned();
                if let Some(mut meta) = meta_opt {
                    let mut missing_idx = None;
                    for i in 0..meta.chunk_count {
                        if !chunk_dir.join(i.to_string()).exists() {
                            missing_idx = Some(i);
                            break;
                        }
                    }

                    if let Some(next_idx) = missing_idx {
                        let req = WireEnvelope::FileChunkRequest {
                            file_hash: file_hash.clone(),
                            chunk_index: next_idx,
                        };
                        if let Ok(json) = serde_json::to_string(&req) {
                            let _ = socket.send_to(json.as_bytes(), src);
                        }
                    } else {
                        let mut full_bytes = Vec::new();
                        for i in 0..meta.chunk_count {
                            if let Ok(c) = fs::read(chunk_dir.join(i.to_string())) {
                                full_bytes.extend_from_slice(&c);
                            }
                        }

                        let mut hasher = Sha256::new();
                        hasher.update(&full_bytes);
                        let computed = hex::encode(hasher.finalize());

                        if computed == file_hash {
                            let comp_dir = inner.data_dir.join("files").join("completed").join(&file_hash);
                            let _ = fs::create_dir_all(&comp_dir);
                            let comp_path = comp_dir.join(&meta.filename);
                            let _ = fs::write(&comp_path, &full_bytes);

                            meta.is_complete = true;
                            inner.files.write().insert(file_hash.clone(), meta.clone());

                            let meta_dir = inner.data_dir.join("files").join("meta");
                            if let Ok(json) = serde_json::to_string_pretty(&meta) {
                                let _ = fs::write(meta_dir.join(format!("{}.json", file_hash)), json);
                            }
                        }
                    }
                }
            }
        }
        WireEnvelope::RoomAnnounce(room) => {
            let mut rooms = inner.rooms.write();
            if !rooms.contains_key(&room.id) {
                let rooms_dir = inner.data_dir.join("rooms");
                let _ = fs::create_dir_all(&rooms_dir);
                if let Ok(json) = serde_json::to_string_pretty(&room) {
                    let _ = fs::write(rooms_dir.join(format!("{}.json", room.id)), json);
                }
                rooms.insert(room.id.clone(), room);
            }
        }
        WireEnvelope::VoteProposal(vote) => {
            let mut proposals = inner.proposals.write();
            if !proposals.contains_key(&vote.proposal_id) {
                proposals.insert(vote.proposal_id.clone(), vote);
            }
        }
        WireEnvelope::VoteBallot {
            proposal_id,
            voter_hash,
            approve,
        } => {
            let mut proposals = inner.proposals.write();
            if let Some(vote) = proposals.get_mut(&proposal_id) {
                if vote.status == "pending" {
                    vote.votes_for.retain(|h| h != &voter_hash);
                    vote.votes_against.retain(|h| h != &voter_hash);
                    if approve {
                        vote.votes_for.push(voter_hash);
                    } else {
                        vote.votes_against.push(voter_hash);
                    }
                }
            }
        }
        WireEnvelope::GovernanceEventBroadcast(event) => {
            let mut audit_log = inner.audit_log.write();
            let events = audit_log.entry(event.room_id.clone()).or_default();
            if !events.iter().any(|e| e.event_id == event.event_id) {
                events.push(event);
            }
        }
    }
}

// --- GLOBAL FFI INSTANCE ---

static GLOBAL_NODE: RwLock<Option<NeighborNode>> = RwLock::new(None);

fn to_c_string(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_init(
    data_dir_c: *const c_char,
    listen_port: u16,
    is_transport: bool,
) -> bool {
    let data_dir_str = if data_dir_c.is_null() {
        "./neighbornet_data".to_string()
    } else {
        unsafe { CStr::from_ptr(data_dir_c).to_string_lossy().into_owned() }
    };

    match NeighborNode::new(PathBuf::from(data_dir_str), listen_port, is_transport) {
        Ok(node) => {
            let mut lock = GLOBAL_NODE.write();
            *lock = Some(node);
            true
        }
        Err(_) => false,
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_stop_node() {
    let mut lock = GLOBAL_NODE.write();
    if let Some(node) = lock.take() {
        node.stop();
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_status_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    let status = node.get_status();
    let json = serde_json::to_string(&status).unwrap_or_default();
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_set_nickname(name_c: *const c_char) -> bool {
    if name_c.is_null() {
        return false;
    }
    let name = unsafe { CStr::from_ptr(name_c).to_string_lossy().into_owned() };
    let lock = GLOBAL_NODE.read();
    if let Some(node) = lock.as_ref() {
        node.set_nickname(name);
        true
    } else {
        false
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_peers_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let list = node.get_peers();
    let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_send_chat(channel_c: *const c_char, content_c: *const c_char) -> bool {
    if channel_c.is_null() || content_c.is_null() {
        return false;
    }
    let channel = unsafe { CStr::from_ptr(channel_c).to_string_lossy().into_owned() };
    let content = unsafe { CStr::from_ptr(content_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.send_chat(channel, content);
    true
}

#[no_mangle]
pub extern "C" fn neighbornet_get_chat_history_json(channel_c: *const c_char) -> *mut c_char {
    let channel = if channel_c.is_null() {
        "general"
    } else {
        unsafe { CStr::from_ptr(channel_c).to_str().unwrap_or("general") }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let msgs = node.get_chat_history(channel);
    let json = serde_json::to_string(&msgs).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_post_bulletin(
    title_c: *const c_char,
    body_c: *const c_char,
    urgency_c: *const c_char,
) -> bool {
    if title_c.is_null() || body_c.is_null() {
        return false;
    }
    let title = unsafe { CStr::from_ptr(title_c).to_string_lossy().into_owned() };
    let body = unsafe { CStr::from_ptr(body_c).to_string_lossy().into_owned() };
    let urgency = if urgency_c.is_null() {
        "normal".to_string()
    } else {
        unsafe { CStr::from_ptr(urgency_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.post_bulletin(title, body, urgency);
    true
}

#[no_mangle]
pub extern "C" fn neighbornet_get_bulletins_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let posts = node.get_bulletins();
    let json = serde_json::to_string(&posts).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_publish_file(
    file_path_c: *const c_char,
    description_c: *const c_char,
) -> *mut c_char {
    if file_path_c.is_null() {
        return std::ptr::null_mut();
    }
    let file_path_str = unsafe { CStr::from_ptr(file_path_c).to_string_lossy().into_owned() };
    let desc_str = if description_c.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(description_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    match node.publish_file(Path::new(&file_path_str), desc_str) {
        Ok(hash) => to_c_string(hash),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_shared_files_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let files = node.get_shared_files();
    let json = serde_json::to_string(&files).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_request_file(file_hash_c: *const c_char) -> bool {
    if file_hash_c.is_null() {
        return false;
    }
    let hash = unsafe { CStr::from_ptr(file_hash_c).to_string_lossy().into_owned() };
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.request_file(&hash)
}

#[no_mangle]
pub extern "C" fn neighbornet_get_file_path(file_hash_c: *const c_char) -> *mut c_char {
    if file_hash_c.is_null() {
        return std::ptr::null_mut();
    }
    let hash = unsafe { CStr::from_ptr(file_hash_c).to_string_lossy().into_owned() };
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    match node.get_completed_file_path(&hash) {
        Some(p) => to_c_string(p.to_string_lossy().into_owned()),
        None => std::ptr::null_mut(),
    }
}

// --- GOVERNANCE FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_create_room(
    name_c: *const c_char,
    description_c: *const c_char,
    is_private: bool,
) -> *mut c_char {
    if name_c.is_null() {
        return std::ptr::null_mut();
    }
    let name = unsafe { CStr::from_ptr(name_c).to_string_lossy().into_owned() };
    let desc = if description_c.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(description_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    let room = node.create_room(name, desc, is_private);
    let json = serde_json::to_string(&room).unwrap_or_default();
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_get_rooms_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let rooms = node.get_rooms();
    let json = serde_json::to_string(&rooms).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_propose_steward_vote(
    room_id_c: *const c_char,
    target_hash_c: *const c_char,
    target_nickname_c: *const c_char,
    action_c: *const c_char,
    reason_cat_c: *const c_char,
    reason_det_c: *const c_char,
) -> *mut c_char {
    if room_id_c.is_null() || target_hash_c.is_null() || action_c.is_null() {
        return std::ptr::null_mut();
    }

    let room_id = unsafe { CStr::from_ptr(room_id_c).to_string_lossy().into_owned() };
    let target_hash = unsafe { CStr::from_ptr(target_hash_c).to_string_lossy().into_owned() };
    let target_nickname = if target_nickname_c.is_null() {
        "Neighbor".to_string()
    } else {
        unsafe { CStr::from_ptr(target_nickname_c).to_string_lossy().into_owned() }
    };
    let action = unsafe { CStr::from_ptr(action_c).to_string_lossy().into_owned() };
    let reason_cat = if reason_cat_c.is_null() {
        "Other".to_string()
    } else {
        unsafe { CStr::from_ptr(reason_cat_c).to_string_lossy().into_owned() }
    };
    let reason_det = if reason_det_c.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(reason_det_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    match node.propose_steward_vote(room_id, target_hash, target_nickname, action, reason_cat, reason_det) {
        Ok(prop_id) => to_c_string(prop_id),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_cast_vote(proposal_id_c: *const c_char, approve: bool) -> bool {
    if proposal_id_c.is_null() {
        return false;
    }
    let prop_id = unsafe { CStr::from_ptr(proposal_id_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.cast_vote(&prop_id, approve)
}

#[no_mangle]
pub extern "C" fn neighbornet_get_proposals_json(room_id_c: *const c_char) -> *mut c_char {
    if room_id_c.is_null() {
        return to_c_string("[]".to_string());
    }
    let room_id = unsafe { CStr::from_ptr(room_id_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let list = node.get_proposals(&room_id);
    let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_get_audit_log_json(room_id_c: *const c_char) -> *mut c_char {
    if room_id_c.is_null() {
        return to_c_string("[]".to_string());
    }
    let room_id = unsafe { CStr::from_ptr(room_id_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let log = node.get_audit_log(&room_id);
    let json = serde_json::to_string(&log).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_panic_wipe() -> bool {
    let lock = GLOBAL_NODE.read();
    if let Some(node) = lock.as_ref() {
        node.panic_wipe().is_ok()
    } else {
        false
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_export_identity_mnemonic() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    match node.export_identity_mnemonic() {
        Ok(phrase) => to_c_string(phrase),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_restore_identity(phrase_or_hex_c: *const c_char) -> *mut c_char {
    if phrase_or_hex_c.is_null() {
        return std::ptr::null_mut();
    }
    let input = unsafe { CStr::from_ptr(phrase_or_hex_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    match node.restore_identity(&input) {
        Ok(new_hash) => to_c_string(new_hash),
        Err(_) => std::ptr::null_mut(),
    }
}

// --- LORA TACTICAL RADIO FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_list_serial_ports_json() -> *mut c_char {
    let list = lora::LoraManager::list_serial_ports();
    let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_connect_lora(
    port_name_c: *const c_char,
    baud_rate: u32,
    freq_hz: u32,
    bw_hz: u32,
    sf: u8,
    cr: u8,
) -> bool {
    if port_name_c.is_null() {
        return false;
    }
    let port_name = unsafe { CStr::from_ptr(port_name_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.inner
        .lora_manager
        .connect(&port_name, baud_rate, freq_hz, bw_hz, sf, cr)
        .is_ok()
}

#[no_mangle]
pub extern "C" fn neighbornet_disconnect_lora() -> bool {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.inner.lora_manager.disconnect();
    true
}

#[no_mangle]
pub extern "C" fn neighbornet_get_lora_status_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return std::ptr::null_mut(),
    };

    let status = node.inner.lora_manager.get_status();
    let json = serde_json::to_string(&status).unwrap_or_default();
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_send_lora_packet(data_c: *const c_char) -> bool {
    if data_c.is_null() {
        return false;
    }
    let data = unsafe { CStr::from_ptr(data_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.inner.lora_manager.send_packet(data.as_bytes())
}

