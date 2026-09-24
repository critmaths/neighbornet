use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString};
use std::fs;
use std::net::{SocketAddr, UdpSocket};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use base64::prelude::*;
use parking_lot::RwLock;
use rand_core::OsRng;
use reticulum_rs::core::identity::{HashIdentity, PrivateIdentity};
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

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "kind")]
pub enum WireEnvelope {
    Announce {
        dest_hash: String,
        nickname: String,
        is_transport: bool,
        bulletin_count: usize,
        file_count: usize,
    },
    Chat(ChatMessage),
    Bulletin(BulletinPost),
    SyncRequest {
        known_bulletin_ids: Vec<String>,
        known_file_hashes: Vec<String>,
    },
    SyncResponse {
        bulletins: Vec<BulletinPost>,
        files: Vec<SharedFileMeta>,
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
    pub uptime_sec: u64,
}

// --- NODE IMPLEMENTATION ---

pub struct NodeInner {
    pub dest_hash_hex: String,
    pub nickname: RwLock<String>,
    pub listen_port: u16,
    pub is_transport: bool,
    pub data_dir: PathBuf,
    pub peers: RwLock<HashMap<String, PeerInfo>>,
    pub messages: RwLock<Vec<ChatMessage>>,
    pub bulletins: RwLock<HashMap<String, BulletinPost>>,
    pub files: RwLock<HashMap<String, SharedFileMeta>>,
    pub seen_ids: RwLock<HashSet<String>>,
    pub running: AtomicBool,
    pub start_time: Instant,
    pub socket: UdpSocket,
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

    // Generate new cryptographic identity via Reticulum-rs
    let identity = PrivateIdentity::new_from_rand(OsRng);
    let hash_hex = hex::encode(identity.as_address_hash_slice());

    // Persist private key
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

        let inner = Arc::new(NodeInner {
            dest_hash_hex,
            nickname: RwLock::new(default_nick),
            listen_port: bound_port,
            is_transport,
            data_dir,
            peers: RwLock::new(HashMap::new()),
            messages: RwLock::new(Vec::new()),
            bulletins: RwLock::new(HashMap::new()),
            files: RwLock::new(loaded_files),
            seen_ids: RwLock::new(HashSet::new()),
            running: AtomicBool::new(true),
            start_time: Instant::now(),
            socket: socket_clone,
        });

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

        // Broadcast to network from bound socket
        let envelope = WireEnvelope::Bulletin(post);
        if let Ok(json) = serde_json::to_string(&envelope) {
            let _ = self.inner.socket.send_to(json.as_bytes(), "255.255.255.255:42424");
            let _ = self.inner.socket.send_to(json.as_bytes(), "127.0.0.1:42424");
            let peer_addrs: Vec<String> = self.inner.peers.read().values().map(|p| p.addr.clone()).collect();
            for addr in peer_addrs {
                if let Ok(dest) = addr.parse::<SocketAddr>() {
                    let _ = self.inner.socket.send_to(json.as_bytes(), dest);
                }
            }
        }

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

        let envelope = WireEnvelope::Chat(chat);
        if let Ok(json) = serde_json::to_string(&envelope) {
            let _ = self.inner.socket.send_to(json.as_bytes(), "255.255.255.255:42424");
            let _ = self.inner.socket.send_to(json.as_bytes(), "127.0.0.1:42424");
            let peer_addrs: Vec<String> = self.inner.peers.read().values().map(|p| p.addr.clone()).collect();
            for addr in peer_addrs {
                if let Ok(dest) = addr.parse::<SocketAddr>() {
                    let _ = self.inner.socket.send_to(json.as_bytes(), dest);
                }
            }
        }

        id
    }

    pub fn get_bulletins(&self) -> Vec<BulletinPost> {
        let mut posts: Vec<BulletinPost> = self.inner.bulletins.read().values().cloned().collect();
        posts.sort_by(|a, b| b.timestamp_sec.cmp(&a.timestamp_sec));
        posts
    }

    pub fn get_chat_history(&self, channel: &str) -> Vec<ChatMessage> {
        self.inner
            .messages
            .read()
            .iter()
            .filter(|m| m.channel == channel)
            .cloned()
            .collect()
    }

    pub fn get_peers(&self) -> Vec<PeerInfo> {
        self.inner.peers.read().values().cloned().collect()
    }

    pub fn connect_peer(&self, addr: SocketAddr) {
        let b_count = self.inner.bulletins.read().len();
        let f_count = self.inner.files.read().len();
        let announce = WireEnvelope::Announce {
            dest_hash: self.inner.dest_hash_hex.clone(),
            nickname: self.inner.nickname.read().clone(),
            is_transport: self.inner.is_transport,
            bulletin_count: b_count,
            file_count: f_count,
        };
        if let Ok(payload) = serde_json::to_string(&announce) {
            let _ = self.inner.socket.send_to(payload.as_bytes(), addr);
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
            (file_bytes.len() + FILE_CHUNK_SIZE - 1) / FILE_CHUNK_SIZE
        };

        // Persist full assembled file
        let comp_dir = self.inner.data_dir.join("files").join("completed").join(&file_hash);
        let _ = fs::create_dir_all(&comp_dir);
        let comp_path = comp_dir.join(&filename);
        let _ = fs::write(&comp_path, &file_bytes);

        // Store individual chunks
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

        // Persist metadata
        let meta_dir = self.inner.data_dir.join("files").join("meta");
        let _ = fs::create_dir_all(&meta_dir);
        if let Ok(json) = serde_json::to_string_pretty(&meta) {
            let _ = fs::write(meta_dir.join(format!("{}.json", file_hash)), json);
        }

        self.inner.files.write().insert(file_hash.clone(), meta.clone());

        // Broadcast file announcement across local network and peers
        let envelope = WireEnvelope::FileAnnounce(meta);
        if let Ok(json) = serde_json::to_string(&envelope) {
            let _ = self.inner.socket.send_to(json.as_bytes(), "255.255.255.255:42424");
            let _ = self.inner.socket.send_to(json.as_bytes(), "127.0.0.1:42424");
            let peer_addrs: Vec<String> = self.inner.peers.read().values().map(|p| p.addr.clone()).collect();
            for addr in peer_addrs {
                if let Ok(dest) = addr.parse::<SocketAddr>() {
                    let _ = self.inner.socket.send_to(json.as_bytes(), dest);
                }
            }
        }

        Ok(file_hash)
    }

    pub fn get_shared_files(&self) -> Vec<SharedFileMeta> {
        let mut list: Vec<SharedFileMeta> = self.inner.files.read().values().cloned().collect();
        list.sort_by(|a, b| b.timestamp_sec.cmp(&a.timestamp_sec));
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
                if let Ok(json) = serde_json::to_string(&req) {
                    let peer_addrs: Vec<String> = self.inner.peers.read().values().map(|p| p.addr.clone()).collect();
                    for addr in peer_addrs {
                        if let Ok(dest) = addr.parse::<SocketAddr>() {
                            let _ = self.inner.socket.send_to(json.as_bytes(), dest);
                        }
                    }
                }
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
            let announce = WireEnvelope::Announce {
                dest_hash: inner_tx.dest_hash_hex.clone(),
                nickname: inner_tx.nickname.read().clone(),
                is_transport: inner_tx.is_transport,
                bulletin_count: b_count,
                file_count: f_count,
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
                };
                if let Ok(json) = serde_json::to_string(&my_announce) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }

            // Sync missing bulletins and file manifests
            let my_b_count = inner.bulletins.read().len();
            let my_f_count = inner.files.read().len();
            if is_new || bulletin_count > my_b_count || file_count > my_f_count {
                let known_b_ids: Vec<String> = inner.bulletins.read().keys().cloned().collect();
                let known_f_hashes: Vec<String> = inner.files.read().keys().cloned().collect();
                let sync_req = WireEnvelope::SyncRequest {
                    known_bulletin_ids: known_b_ids,
                    known_file_hashes: known_f_hashes,
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
                messages.push(msg);
            }
        }
        WireEnvelope::Bulletin(post) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(post.id.clone()) {
                let mut bulletins = inner.bulletins.write();
                bulletins.insert(post.id.clone(), post);
            }
        }
        WireEnvelope::SyncRequest {
            known_bulletin_ids,
            known_file_hashes,
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

            if !missing_bulletins.is_empty() || !missing_files.is_empty() {
                let resp = WireEnvelope::SyncResponse {
                    bulletins: missing_bulletins,
                    files: missing_files,
                };
                if let Ok(json) = serde_json::to_string(&resp) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::SyncResponse { bulletins, files } => {
            let mut seen = inner.seen_ids.write();
            let mut stored_b = inner.bulletins.write();
            for b in bulletins {
                if seen.insert(b.id.clone()) {
                    stored_b.insert(b.id.clone(), b);
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
                        // Request next missing chunk from source peer
                        let req = WireEnvelope::FileChunkRequest {
                            file_hash: file_hash.clone(),
                            chunk_index: next_idx,
                        };
                        if let Ok(json) = serde_json::to_string(&req) {
                            let _ = socket.send_to(json.as_bytes(), src);
                        }
                    } else {
                        // All chunks assembled!
                        let mut full_bytes = Vec::new();
                        for i in 0..meta.chunk_count {
                            if let Ok(c) = fs::read(chunk_dir.join(i.to_string())) {
                                full_bytes.extend_from_slice(&c);
                            }
                        }

                        // Cryptographic verification
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
