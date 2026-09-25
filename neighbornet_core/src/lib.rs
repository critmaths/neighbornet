#![allow(clippy::not_unsafe_ptr_arg_deref)]

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
pub struct UserProfile {
    pub dest_hash: String,
    pub nickname: String,
    pub bio: String,
    pub avatar_base64: String,
    pub callsign: String,
    pub contact_info: String,
    pub neighborhood_zone: String,
    pub skills: Vec<String>,
    pub updated_at_sec: u64,
}

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
    #[serde(default)]
    pub audio_base64: Option<String>,
    #[serde(default)]
    pub audio_duration_sec: Option<u32>,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct TacticalMarker {
    pub id: String,
    pub title: String,
    pub category: String, // "medical", "water", "shelter", "hazard", "checkpoint", "relay", "sos"
    pub description: String,
    pub lat: f64,
    pub lon: f64,
    pub author_hash: String,
    pub author_nickname: String,
    pub author_callsign: String,
    pub timestamp_sec: u64,
    pub is_active: bool,
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

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq)]
pub struct FormFieldDef {
    pub id: String,
    pub label: String,
    pub field_type: String, // "text", "number", "select", "checkbox", "datetime"
    pub required: bool,
    #[serde(default)]
    pub options: Vec<String>,
    #[serde(default)]
    pub default_value: Option<String>,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct FormSchema {
    pub id: String,
    pub title: String,
    pub category: String, // "triage", "logistics", "barter", "rollcall", "custom"
    pub description: String,
    pub author_hash: String,
    pub author_nickname: String,
    pub fields: Vec<FormFieldDef>,
    pub created_at: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct FormEntry {
    pub id: String,
    pub schema_id: String,
    pub author_hash: String,
    pub author_nickname: String,
    pub data_json: String,
    pub timestamp_sec: u64,
    pub signature_hex: String,
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
        #[serde(default)]
        known_schema_ids: Vec<String>,
        #[serde(default)]
        known_entry_ids: Vec<String>,
        #[serde(default)]
        known_profile_hashes: Vec<String>,
        #[serde(default)]
        known_marker_ids: Vec<String>,
    },
    SyncResponse {
        bulletins: Vec<BulletinPost>,
        files: Vec<SharedFileMeta>,
        rooms: Vec<RoomMeta>,
        #[serde(default)]
        schemas: Vec<FormSchema>,
        #[serde(default)]
        entries: Vec<FormEntry>,
        #[serde(default)]
        profiles: Vec<UserProfile>,
        #[serde(default)]
        markers: Vec<TacticalMarker>,
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
    FormSchemaAnnounce(FormSchema),
    FormEntryAnnounce(FormEntry),
    ProfileAnnounce(UserProfile),
    ProfileRequest {
        dest_hash: String,
    },
    PttVoice(PttVoiceChunk),
    PttFloor(PttFloorSignal),
    MarkerAnnounce(TacticalMarker),
    MarkerDelete(String),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PttVoiceChunk {
    pub session_id: String,
    pub sequence: u32,
    pub channel: String,
    pub sender_hash: String,
    pub sender_nickname: String,
    pub sender_callsign: String,
    pub audio_base64: String,
    pub is_final: bool,
    pub priority: String,
    pub timestamp_sec: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PttFloorSignal {
    pub channel: String,
    pub speaker_hash: String,
    pub speaker_nickname: String,
    pub speaker_callsign: String,
    pub is_transmitting: bool,
    pub priority: String,
    pub timestamp_sec: u64,
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
    pub form_schemas: RwLock<HashMap<String, FormSchema>>,
    pub form_entries: RwLock<HashMap<String, Vec<FormEntry>>>,
    pub user_profiles: RwLock<HashMap<String, UserProfile>>,
    pub markers: RwLock<HashMap<String, TacticalMarker>>,
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

fn default_form_schemas(author_hash: &str, author_nick: &str) -> Vec<FormSchema> {
    vec![
        FormSchema {
            id: "schema-med-triage-start".to_string(),
            title: "Disaster Medical Triage (START)".to_string(),
            category: "triage".to_string(),
            description: "Simple Triage and Rapid Treatment protocol for field mass casualty triage.".to_string(),
            author_hash: author_hash.to_string(),
            author_nickname: author_nick.to_string(),
            created_at: 1700000000,
            fields: vec![
                FormFieldDef {
                    id: "patient_tag".to_string(),
                    label: "Patient ID / Tag #".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "triage_color".to_string(),
                    label: "Triage Category".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Red (Immediate)".to_string(),
                        "Yellow (Delayed)".to_string(),
                        "Green (Minor)".to_string(),
                        "Black (Expectant/Deceased)".to_string(),
                    ],
                    default_value: Some("Yellow (Delayed)".to_string()),
                },
                FormFieldDef {
                    id: "can_walk".to_string(),
                    label: "Can Walk / Ambulatory".to_string(),
                    field_type: "checkbox".to_string(),
                    required: false,
                    options: vec![],
                    default_value: Some("false".to_string()),
                },
                FormFieldDef {
                    id: "respirations".to_string(),
                    label: "Respiration Rate".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Normal (<30/min)".to_string(),
                        "Rapid (>30/min)".to_string(),
                        "Absent / Apnea".to_string(),
                    ],
                    default_value: Some("Normal (<30/min)".to_string()),
                },
                FormFieldDef {
                    id: "perfusion".to_string(),
                    label: "Perfusion / Radial Pulse".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Radial Pulse Present".to_string(),
                        "No Pulse / Cap Refill >2s".to_string(),
                    ],
                    default_value: Some("Radial Pulse Present".to_string()),
                },
                FormFieldDef {
                    id: "mental_status".to_string(),
                    label: "Mental Status".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Follows Simple Commands".to_string(),
                        "Altered / Unresponsive".to_string(),
                    ],
                    default_value: Some("Follows Simple Commands".to_string()),
                },
                FormFieldDef {
                    id: "location".to_string(),
                    label: "Field Staging Location".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "chief_complaint".to_string(),
                    label: "Injuries / Chief Complaint".to_string(),
                    field_type: "text".to_string(),
                    required: false,
                    options: vec![],
                    default_value: None,
                },
            ],
        },
        FormSchema {
            id: "schema-ration-distribution".to_string(),
            title: "Emergency Water & Supply Ration Log".to_string(),
            category: "logistics".to_string(),
            description: "Structured distribution tracking for water, rations, fuel, and medical packs.".to_string(),
            author_hash: author_hash.to_string(),
            author_nickname: author_nick.to_string(),
            created_at: 1700000000,
            fields: vec![
                FormFieldDef {
                    id: "distribution_station".to_string(),
                    label: "Distribution Station / Hub".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "recipient_id".to_string(),
                    label: "Recipient / Household ID".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "family_size".to_string(),
                    label: "Household Headcount".to_string(),
                    field_type: "number".to_string(),
                    required: true,
                    options: vec![],
                    default_value: Some("1".to_string()),
                },
                FormFieldDef {
                    id: "resource_type".to_string(),
                    label: "Resource Dispensed".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Potable Water (Gallons)".to_string(),
                        "MRE / Food Ration Packs".to_string(),
                        "Generator Fuel (Gallons)".to_string(),
                        "Medical / First-Aid Kit".to_string(),
                        "Batteries / Solar Lanterns".to_string(),
                    ],
                    default_value: Some("Potable Water (Gallons)".to_string()),
                },
                FormFieldDef {
                    id: "quantity".to_string(),
                    label: "Quantity Dispensed".to_string(),
                    field_type: "number".to_string(),
                    required: true,
                    options: vec![],
                    default_value: Some("1".to_string()),
                },
                FormFieldDef {
                    id: "notes".to_string(),
                    label: "Special Needs / Notes".to_string(),
                    field_type: "text".to_string(),
                    required: false,
                    options: vec![],
                    default_value: None,
                },
            ],
        },
        FormSchema {
            id: "schema-barter-ledger".to_string(),
            title: "Community Mutual Aid & Barter Ledger".to_string(),
            category: "barter".to_string(),
            description: "Decentralized trade ledger for peer-to-peer bartering and mutual aid coordination.".to_string(),
            author_hash: author_hash.to_string(),
            author_nickname: author_nick.to_string(),
            created_at: 1700000000,
            fields: vec![
                FormFieldDef {
                    id: "listing_type".to_string(),
                    label: "Offer or Request".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Offering Item/Skill".to_string(),
                        "Requesting / ISO".to_string(),
                    ],
                    default_value: Some("Offering Item/Skill".to_string()),
                },
                FormFieldDef {
                    id: "item_title".to_string(),
                    label: "Item / Service Title".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "barter_terms".to_string(),
                    label: "Wanted in Exchange".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "contact_location".to_string(),
                    label: "Contact Location / Stand / Channel".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "urgency_level".to_string(),
                    label: "Urgency Level".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "Standard".to_string(),
                        "Urgent".to_string(),
                        "Critical Need".to_string(),
                    ],
                    default_value: Some("Standard".to_string()),
                },
            ],
        },
        FormSchema {
            id: "schema-roll-call".to_string(),
            title: "Disaster Roll-Call & Safety Check-in".to_string(),
            category: "rollcall".to_string(),
            description: "Household safety verification and wellness census for community defense/relief.".to_string(),
            author_hash: author_hash.to_string(),
            author_nickname: author_nick.to_string(),
            created_at: 1700000000,
            fields: vec![
                FormFieldDef {
                    id: "household_name".to_string(),
                    label: "Household / Group Name".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "status".to_string(),
                    label: "Safety Status".to_string(),
                    field_type: "select".to_string(),
                    required: true,
                    options: vec![
                        "All Safe / OK".to_string(),
                        "Minor Injuries".to_string(),
                        "Critical Emergency / Trapped".to_string(),
                        "Need Supplies / Power".to_string(),
                    ],
                    default_value: Some("All Safe / OK".to_string()),
                },
                FormFieldDef {
                    id: "people_count".to_string(),
                    label: "Number of People in Group".to_string(),
                    field_type: "number".to_string(),
                    required: true,
                    options: vec![],
                    default_value: Some("1".to_string()),
                },
                FormFieldDef {
                    id: "shelter_location".to_string(),
                    label: "Shelter Location / Address".to_string(),
                    field_type: "text".to_string(),
                    required: true,
                    options: vec![],
                    default_value: None,
                },
                FormFieldDef {
                    id: "needs_rescue".to_string(),
                    label: "Immediate Rescue Required".to_string(),
                    field_type: "checkbox".to_string(),
                    required: false,
                    options: vec![],
                    default_value: Some("false".to_string()),
                },
                FormFieldDef {
                    id: "details".to_string(),
                    label: "Status Details / Remarks".to_string(),
                    field_type: "text".to_string(),
                    required: false,
                    options: vec![],
                    default_value: None,
                },
            ],
        },
    ]
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
               timestamp_sec INTEGER NOT NULL,
               audio_base64 TEXT,
               audio_duration_sec INTEGER
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
             );

             CREATE TABLE IF NOT EXISTS markers (
               id TEXT PRIMARY KEY,
               title TEXT NOT NULL,
               category TEXT NOT NULL,
               description TEXT NOT NULL,
               lat REAL NOT NULL,
               lon REAL NOT NULL,
               author_hash TEXT NOT NULL,
               author_nickname TEXT NOT NULL,
               author_callsign TEXT NOT NULL,
               timestamp_sec INTEGER NOT NULL,
               is_active INTEGER NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_markers_timestamp ON markers(timestamp_sec);

             CREATE TABLE IF NOT EXISTS form_schemas (
               id TEXT PRIMARY KEY,
               title TEXT NOT NULL,
               category TEXT NOT NULL,
               description TEXT NOT NULL,
               author_hash TEXT NOT NULL,
               author_nickname TEXT NOT NULL,
               fields_json TEXT NOT NULL,
               created_at INTEGER NOT NULL
             );

             CREATE TABLE IF NOT EXISTS form_entries (
               id TEXT PRIMARY KEY,
               schema_id TEXT NOT NULL,
               author_hash TEXT NOT NULL,
               author_nickname TEXT NOT NULL,
               data_json TEXT NOT NULL,
               timestamp_sec INTEGER NOT NULL,
               signature_hex TEXT NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_form_entries_schema ON form_entries(schema_id);
             CREATE INDEX IF NOT EXISTS idx_form_entries_timestamp ON form_entries(timestamp_sec);

              CREATE TABLE IF NOT EXISTS user_profiles (
                dest_hash TEXT PRIMARY KEY,
                nickname TEXT NOT NULL,
                bio TEXT NOT NULL,
                avatar_base64 TEXT NOT NULL,
                callsign TEXT NOT NULL,
                contact_info TEXT NOT NULL,
                neighborhood_zone TEXT NOT NULL,
                skills_json TEXT NOT NULL,
                updated_at_sec INTEGER NOT NULL
              );"
        ).map_err(|e| format!("Failed to initialize DB schema: {}", e))?;

        let _ = db.execute("ALTER TABLE messages ADD COLUMN audio_base64 TEXT", []);
        let _ = db.execute("ALTER TABLE messages ADD COLUMN audio_duration_sec INTEGER", []);

        let mut loaded_messages = Vec::new();
        if let Ok(mut stmt) = db.prepare("SELECT id, channel, sender_hash, sender_nickname, content, timestamp_sec, audio_base64, audio_duration_sec FROM messages ORDER BY timestamp_sec ASC") {
            if let Ok(msg_iter) = stmt.query_map([], |row| {
                Ok(ChatMessage {
                    id: row.get(0)?,
                    channel: row.get(1)?,
                    sender_hash: row.get(2)?,
                    sender_nickname: row.get(3)?,
                    content: row.get(4)?,
                    timestamp_sec: row.get(5)?,
                    audio_base64: row.get(6).ok(),
                    audio_duration_sec: row.get(7).ok(),
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

        let mut loaded_schemas = HashMap::new();
        if let Ok(mut stmt) = db.prepare("SELECT id, title, category, description, author_hash, author_nickname, fields_json, created_at FROM form_schemas") {
            if let Ok(schema_iter) = stmt.query_map([], |row| {
                let fields_json: String = row.get(6)?;
                let fields: Vec<FormFieldDef> = serde_json::from_str(&fields_json).unwrap_or_default();
                Ok(FormSchema {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    category: row.get(2)?,
                    description: row.get(3)?,
                    author_hash: row.get(4)?,
                    author_nickname: row.get(5)?,
                    fields,
                    created_at: row.get(7)?,
                })
            }) {
                for s in schema_iter.flatten() {
                    loaded_schemas.insert(s.id.clone(), s);
                }
            }
        }
        if loaded_schemas.is_empty() {
            for s in default_form_schemas(&dest_hash_hex, &default_nick) {
                let fields_json = serde_json::to_string(&s.fields).unwrap_or_default();
                let _ = db.execute(
                    "INSERT OR IGNORE INTO form_schemas (id, title, category, description, author_hash, author_nickname, fields_json, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                    rusqlite::params![s.id, s.title, s.category, s.description, s.author_hash, s.author_nickname, fields_json, s.created_at],
                );
                loaded_schemas.insert(s.id.clone(), s);
            }
        }

        let mut loaded_entries: HashMap<String, Vec<FormEntry>> = HashMap::new();
        let mut seen_ids = HashSet::new();
        for msg in &loaded_messages { seen_ids.insert(msg.id.clone()); }
        for id in loaded_bulletins.keys() { seen_ids.insert(id.clone()); }
        for id in loaded_schemas.keys() { seen_ids.insert(id.clone()); }

        if let Ok(mut stmt) = db.prepare("SELECT id, schema_id, author_hash, author_nickname, data_json, timestamp_sec, signature_hex FROM form_entries ORDER BY timestamp_sec ASC") {
            if let Ok(entry_iter) = stmt.query_map([], |row| {
                Ok(FormEntry {
                    id: row.get(0)?,
                    schema_id: row.get(1)?,
                    author_hash: row.get(2)?,
                    author_nickname: row.get(3)?,
                    data_json: row.get(4)?,
                    timestamp_sec: row.get(5)?,
                    signature_hex: row.get(6)?,
                })
            }) {
                for e in entry_iter.flatten() {
                    seen_ids.insert(e.id.clone());
                    loaded_entries.entry(e.schema_id.clone()).or_default().push(e);
                }
            }
        }

        let mut loaded_profiles = HashMap::new();
        if let Ok(mut stmt) = db.prepare("SELECT dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec FROM user_profiles") {
            if let Ok(prof_iter) = stmt.query_map([], |row| {
                let skills_json: String = row.get(7)?;
                let skills: Vec<String> = serde_json::from_str(&skills_json).unwrap_or_default();
                Ok(UserProfile {
                    dest_hash: row.get(0)?,
                    nickname: row.get(1)?,
                    bio: row.get(2)?,
                    avatar_base64: row.get(3)?,
                    callsign: row.get(4)?,
                    contact_info: row.get(5)?,
                    neighborhood_zone: row.get(6)?,
                    skills,
                    updated_at_sec: row.get(8)?,
                })
            }) {
                for p in prof_iter.flatten() {
                    loaded_profiles.insert(p.dest_hash.clone(), p);
                }
            }
        }

        let mut loaded_markers = HashMap::new();
        if let Ok(mut stmt) = db.prepare("SELECT id, title, category, description, lat, lon, author_hash, author_nickname, author_callsign, timestamp_sec, is_active FROM markers") {
            if let Ok(marker_iter) = stmt.query_map([], |row| {
                let is_act: i64 = row.get(10)?;
                Ok(TacticalMarker {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    category: row.get(2)?,
                    description: row.get(3)?,
                    lat: row.get(4)?,
                    lon: row.get(5)?,
                    author_hash: row.get(6)?,
                    author_nickname: row.get(7)?,
                    author_callsign: row.get(8)?,
                    timestamp_sec: row.get(9)?,
                    is_active: is_act != 0,
                })
            }) {
                for m in marker_iter.flatten() {
                    seen_ids.insert(m.id.clone());
                    loaded_markers.insert(m.id.clone(), m);
                }
            }
        }

        let effective_nick = match loaded_profiles.get(&dest_hash_hex) {
            Some(my_prof) => my_prof.nickname.clone(),
            None => {
                let initial_profile = UserProfile {
                    dest_hash: dest_hash_hex.clone(),
                    nickname: default_nick.clone(),
                    bio: String::new(),
                    avatar_base64: String::new(),
                    callsign: String::new(),
                    contact_info: String::new(),
                    neighborhood_zone: String::new(),
                    skills: vec![],
                    updated_at_sec: current_epoch_sec(),
                };
                let skills_json = serde_json::to_string(&initial_profile.skills).unwrap_or_default();
                let _ = db.execute(
                    "INSERT OR IGNORE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                    rusqlite::params![
                        initial_profile.dest_hash,
                        initial_profile.nickname,
                        initial_profile.bio,
                        initial_profile.avatar_base64,
                        initial_profile.callsign,
                        initial_profile.contact_info,
                        initial_profile.neighborhood_zone,
                        skills_json,
                        initial_profile.updated_at_sec
                    ],
                );
                loaded_profiles.insert(dest_hash_hex.clone(), initial_profile);
                default_nick
            }
        };

        let lora_mgr = Arc::new(lora::LoraManager::new());

        let inner = Arc::new(NodeInner {
            dest_hash_hex,
            nickname: RwLock::new(effective_nick),
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
            form_schemas: RwLock::new(loaded_schemas),
            form_entries: RwLock::new(loaded_entries),
            user_profiles: RwLock::new(loaded_profiles),
            markers: RwLock::new(loaded_markers),
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
        *self.inner.nickname.write() = name.clone();
        let mut profiles = self.inner.user_profiles.write();
        let mut prof = match profiles.get(&self.inner.dest_hash_hex) {
            Some(p) => p.clone(),
            None => UserProfile {
                dest_hash: self.inner.dest_hash_hex.clone(),
                nickname: name.clone(),
                bio: String::new(),
                avatar_base64: String::new(),
                callsign: String::new(),
                contact_info: String::new(),
                neighborhood_zone: String::new(),
                skills: vec![],
                updated_at_sec: current_epoch_sec(),
            },
        };
        prof.nickname = name;
        prof.updated_at_sec = current_epoch_sec();
        if let Ok(db) = self.inner.db.lock() {
            let skills_json = serde_json::to_string(&prof.skills).unwrap_or_default();
            let _ = db.execute(
                "INSERT OR REPLACE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                rusqlite::params![
                    prof.dest_hash,
                    prof.nickname,
                    prof.bio,
                    prof.avatar_base64,
                    prof.callsign,
                    prof.contact_info,
                    prof.neighborhood_zone,
                    skills_json,
                    prof.updated_at_sec
                ],
            );
        }
        profiles.insert(self.inner.dest_hash_hex.clone(), prof.clone());
        let envelope = WireEnvelope::ProfileAnnounce(prof);
        self.broadcast_envelope(&envelope);
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
        self.send_voice_chat(channel, content, None, None)
    }

    pub fn send_voice_chat(
        &self,
        channel: String,
        content: String,
        audio_base64: Option<String>,
        audio_duration_sec: Option<u32>,
    ) -> String {
        let timestamp = current_epoch_sec();
        let raw_id = format!(
            "{}:{}:{}:{}:{:?}",
            self.inner.dest_hash_hex, channel, content, timestamp, audio_base64
        );
        let id = compute_hash(&raw_id);

        let chat = ChatMessage {
            id: id.clone(),
            channel,
            sender_hash: self.inner.dest_hash_hex.clone(),
            sender_nickname: self.inner.nickname.read().clone(),
            content,
            timestamp_sec: timestamp,
            audio_base64,
            audio_duration_sec,
        };

        self.inner.seen_ids.write().insert(id.clone());
        self.inner.messages.write().push(chat.clone());

        if let Ok(db) = self.inner.db.lock() {
            let _ = db.execute(
                "INSERT OR IGNORE INTO messages (id, channel, sender_hash, sender_nickname, content, timestamp_sec, audio_base64, audio_duration_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                rusqlite::params![
                    chat.id,
                    chat.channel,
                    chat.sender_hash,
                    chat.sender_nickname,
                    chat.content,
                    chat.timestamp_sec,
                    chat.audio_base64,
                    chat.audio_duration_sec
                ],
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
            if let Ok(mut stmt) = db.prepare("SELECT id, channel, sender_hash, sender_nickname, content, timestamp_sec, audio_base64, audio_duration_sec FROM messages WHERE channel = ?1 ORDER BY timestamp_sec ASC") {
                if let Ok(msg_iter) = stmt.query_map(rusqlite::params![channel], |row| {
                    Ok(ChatMessage {
                        id: row.get(0)?,
                        channel: row.get(1)?,
                        sender_hash: row.get(2)?,
                        sender_nickname: row.get(3)?,
                        content: row.get(4)?,
                        timestamp_sec: row.get(5)?,
                        audio_base64: row.get(6).ok(),
                        audio_duration_sec: row.get(7).ok(),
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

    // --- TACTICAL MESH MAP & COMMUNITY MARKERS ---

    pub fn get_markers(&self) -> Vec<TacticalMarker> {
        self.inner.markers.read().values().cloned().collect()
    }

    pub fn upsert_marker(&self, mut marker: TacticalMarker) -> Result<TacticalMarker, String> {
        if marker.id.is_empty() {
            let timestamp = current_epoch_sec();
            let raw_id = format!("{}:{}:{}:{}:{}", self.inner.dest_hash_hex, marker.title, marker.lat, marker.lon, timestamp);
            marker.id = format!("marker-{}", &compute_hash(&raw_id)[..16]);
            marker.author_hash = self.inner.dest_hash_hex.clone();
            marker.author_nickname = self.inner.nickname.read().clone();
            marker.author_callsign = self.get_my_profile().callsign;
            marker.timestamp_sec = timestamp;
        }

        if let Ok(db) = self.inner.db.lock() {
            let is_act = if marker.is_active { 1 } else { 0 };
            let _ = db.execute(
                "INSERT OR REPLACE INTO markers (id, title, category, description, lat, lon, author_hash, author_nickname, author_callsign, timestamp_sec, is_active) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                rusqlite::params![
                    marker.id,
                    marker.title,
                    marker.category,
                    marker.description,
                    marker.lat,
                    marker.lon,
                    marker.author_hash,
                    marker.author_nickname,
                    marker.author_callsign,
                    marker.timestamp_sec,
                    is_act
                ],
            );
        }

        self.inner.markers.write().insert(marker.id.clone(), marker.clone());
        self.inner.seen_ids.write().insert(marker.id.clone());

        let envelope = WireEnvelope::MarkerAnnounce(marker.clone());
        self.broadcast_envelope(&envelope);

        Ok(marker)
    }

    pub fn delete_marker(&self, marker_id: &str) -> bool {
        self.inner.markers.write().remove(marker_id);
        if let Ok(db) = self.inner.db.lock() {
            let _ = db.execute("DELETE FROM markers WHERE id = ?1", rusqlite::params![marker_id]);
        }
        let envelope = WireEnvelope::MarkerDelete(marker_id.to_string());
        self.broadcast_envelope(&envelope);
        true
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

    pub fn send_ptt_chunk(&self, chunk: PttVoiceChunk) {
        self.broadcast_envelope(&WireEnvelope::PttVoice(chunk));
    }

    pub fn send_ptt_floor(&self, signal: PttFloorSignal) {
        self.broadcast_envelope(&WireEnvelope::PttFloor(signal));
    }

    // --- SOVEREIGN PROFILES & TACTICAL IDENTITY ---

    pub fn get_my_profile(&self) -> UserProfile {
        let profiles = self.inner.user_profiles.read();
        if let Some(prof) = profiles.get(&self.inner.dest_hash_hex) {
            return prof.clone();
        }
        UserProfile {
            dest_hash: self.inner.dest_hash_hex.clone(),
            nickname: self.inner.nickname.read().clone(),
            bio: String::new(),
            avatar_base64: String::new(),
            callsign: String::new(),
            contact_info: String::new(),
            neighborhood_zone: String::new(),
            skills: vec![],
            updated_at_sec: current_epoch_sec(),
        }
    }

    pub fn update_my_profile(&self, mut profile: UserProfile) -> Result<UserProfile, String> {
        profile.dest_hash = self.inner.dest_hash_hex.clone();
        profile.updated_at_sec = current_epoch_sec();

        if !profile.nickname.is_empty() {
            *self.inner.nickname.write() = profile.nickname.clone();
        }

        if let Ok(db) = self.inner.db.lock() {
            let skills_json = serde_json::to_string(&profile.skills).unwrap_or_default();
            let _ = db.execute(
                "INSERT OR REPLACE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                rusqlite::params![
                    profile.dest_hash,
                    profile.nickname,
                    profile.bio,
                    profile.avatar_base64,
                    profile.callsign,
                    profile.contact_info,
                    profile.neighborhood_zone,
                    skills_json,
                    profile.updated_at_sec
                ],
            );
        }

        self.inner.user_profiles.write().insert(profile.dest_hash.clone(), profile.clone());

        let envelope = WireEnvelope::ProfileAnnounce(profile.clone());
        self.broadcast_envelope(&envelope);

        Ok(profile)
    }

    pub fn get_peer_profile(&self, dest_hash: &str) -> Option<UserProfile> {
        self.inner.user_profiles.read().get(dest_hash).cloned()
    }

    pub fn get_all_profiles(&self) -> Vec<UserProfile> {
        self.inner.user_profiles.read().values().cloned().collect()
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

    // --- DECLARATIVE OFFLINE FORM / COMMUNITY LEDGER SUBSYSTEM ---

    pub fn get_form_schemas(&self) -> Vec<FormSchema> {
        let mut list: Vec<FormSchema> = self.inner.form_schemas.read().values().cloned().collect();
        list.sort_by_key(|s| s.created_at);
        list
    }

    pub fn create_form_schema(
        &self,
        title: String,
        description: String,
        category: String,
        fields: Vec<FormFieldDef>,
    ) -> Result<FormSchema, String> {
        let now = current_epoch_sec();
        let author_hash = self.inner.dest_hash_hex.clone();
        let author_nickname = self.inner.nickname.read().clone();
        let id = format!(
            "schema-{}",
            &compute_hash(&format!("{}:{}:{}:{}", title, category, author_hash, now))[..16]
        );

        let schema = FormSchema {
            id: id.clone(),
            title,
            category,
            description,
            author_hash: author_hash.clone(),
            author_nickname: author_nickname.clone(),
            fields,
            created_at: now,
        };

        if let Ok(db) = self.inner.db.lock() {
            let fields_json = serde_json::to_string(&schema.fields).unwrap_or_default();
            let _ = db.execute(
                "INSERT OR REPLACE INTO form_schemas (id, title, category, description, author_hash, author_nickname, fields_json, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                rusqlite::params![
                    schema.id,
                    schema.title,
                    schema.category,
                    schema.description,
                    schema.author_hash,
                    schema.author_nickname,
                    fields_json,
                    schema.created_at
                ],
            );
        }

        self.inner.form_schemas.write().insert(id.clone(), schema.clone());
        self.inner.seen_ids.write().insert(id);

        let envelope = WireEnvelope::FormSchemaAnnounce(schema.clone());
        self.broadcast_envelope(&envelope);

        Ok(schema)
    }

    pub fn get_form_entries(&self, schema_id: &str) -> Vec<FormEntry> {
        let mut list = match self.inner.form_entries.read().get(schema_id) {
            Some(entries) => entries.clone(),
            None => Vec::new(),
        };
        list.sort_by_key(|e| std::cmp::Reverse(e.timestamp_sec));
        list
    }

    pub fn submit_form_entry(&self, schema_id: String, data_json: String) -> Result<FormEntry, String> {
        let now = current_epoch_sec();
        let author_hash = self.inner.dest_hash_hex.clone();
        let author_nickname = self.inner.nickname.read().clone();
        let entry_id = format!(
            "entry-{}",
            &compute_hash(&format!("{}:{}:{}:{}", schema_id, author_hash, data_json, now))[..16]
        );
        let signature_hex = compute_hash(&format!("{}:{}:{}:{}", entry_id, schema_id, author_hash, data_json));

        let entry = FormEntry {
            id: entry_id.clone(),
            schema_id: schema_id.clone(),
            author_hash,
            author_nickname,
            data_json,
            timestamp_sec: now,
            signature_hex,
        };

        if let Ok(db) = self.inner.db.lock() {
            let _ = db.execute(
                "INSERT OR IGNORE INTO form_entries (id, schema_id, author_hash, author_nickname, data_json, timestamp_sec, signature_hex) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                rusqlite::params![
                    entry.id,
                    entry.schema_id,
                    entry.author_hash,
                    entry.author_nickname,
                    entry.data_json,
                    entry.timestamp_sec,
                    entry.signature_hex
                ],
            );
        }

        let mut entries_guard = self.inner.form_entries.write();
        entries_guard.entry(schema_id).or_default().push(entry.clone());
        drop(entries_guard);
        self.inner.seen_ids.write().insert(entry_id);

        let envelope = WireEnvelope::FormEntryAnnounce(entry.clone());
        self.broadcast_envelope(&envelope);

        Ok(entry)
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
        self.inner.form_schemas.write().clear();
        self.inner.form_entries.write().clear();
        self.inner.user_profiles.write().clear();
        self.inner.markers.write().clear();
        self.inner.seen_ids.write().clear();

        // 2. Drop and securely reset SQLite tables
        if let Ok(conn) = self.inner.db.lock() {
            let _ = conn.execute("DROP TABLE IF EXISTS messages", []);
            let _ = conn.execute("DROP TABLE IF EXISTS bulletins", []);
            let _ = conn.execute("DROP TABLE IF EXISTS markers", []);
            let _ = conn.execute("DROP TABLE IF EXISTS form_schemas", []);
            let _ = conn.execute("DROP TABLE IF EXISTS form_entries", []);
            let _ = conn.execute("DROP TABLE IF EXISTS user_profiles", []);
            let _ = conn.execute("VACUUM", []);

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    channel TEXT NOT NULL,
                    sender_hash TEXT NOT NULL,
                    sender_nickname TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp_sec INTEGER NOT NULL,
                    audio_base64 TEXT,
                    audio_duration_sec INTEGER
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

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS markers (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    category TEXT NOT NULL,
                    description TEXT NOT NULL,
                    lat REAL NOT NULL,
                    lon REAL NOT NULL,
                    author_hash TEXT NOT NULL,
                    author_nickname TEXT NOT NULL,
                    author_callsign TEXT NOT NULL,
                    timestamp_sec INTEGER NOT NULL,
                    is_active INTEGER NOT NULL
                )",
                [],
            );
            let _ = conn.execute("CREATE INDEX IF NOT EXISTS idx_markers_timestamp ON markers(timestamp_sec)", []);

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS form_schemas (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    category TEXT NOT NULL,
                    description TEXT NOT NULL,
                    author_hash TEXT NOT NULL,
                    author_nickname TEXT NOT NULL,
                    fields_json TEXT NOT NULL,
                    created_at INTEGER NOT NULL
                )",
                [],
            );

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS form_entries (
                    id TEXT PRIMARY KEY,
                    schema_id TEXT NOT NULL,
                    author_hash TEXT NOT NULL,
                    author_nickname TEXT NOT NULL,
                    data_json TEXT NOT NULL,
                    timestamp_sec INTEGER NOT NULL,
                    signature_hex TEXT NOT NULL
                )",
                [],
            );
            let _ = conn.execute("CREATE INDEX IF NOT EXISTS idx_form_entries_schema ON form_entries(schema_id)", []);
            let _ = conn.execute("CREATE INDEX IF NOT EXISTS idx_form_entries_timestamp ON form_entries(timestamp_sec)", []);

            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS user_profiles (
                    dest_hash TEXT PRIMARY KEY,
                    nickname TEXT NOT NULL,
                    bio TEXT NOT NULL,
                    avatar_base64 TEXT NOT NULL,
                    callsign TEXT NOT NULL,
                    contact_info TEXT NOT NULL,
                    neighborhood_zone TEXT NOT NULL,
                    skills_json TEXT NOT NULL,
                    updated_at_sec INTEGER NOT NULL
                )",
                [],
            );
        }

        let initial_prof = UserProfile {
            dest_hash: self.inner.dest_hash_hex.clone(),
            nickname: self.inner.nickname.read().clone(),
            bio: String::new(),
            avatar_base64: String::new(),
            callsign: String::new(),
            contact_info: String::new(),
            neighborhood_zone: String::new(),
            skills: vec![],
            updated_at_sec: current_epoch_sec(),
        };
        if let Ok(conn) = self.inner.db.lock() {
            let skills_json = serde_json::to_string(&initial_prof.skills).unwrap_or_default();
            let _ = conn.execute(
                "INSERT OR IGNORE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                rusqlite::params![
                    initial_prof.dest_hash,
                    initial_prof.nickname,
                    initial_prof.bio,
                    initial_prof.avatar_base64,
                    initial_prof.callsign,
                    initial_prof.contact_info,
                    initial_prof.neighborhood_zone,
                    skills_json,
                    initial_prof.updated_at_sec
                ],
            );
        }
        self.inner.user_profiles.write().insert(self.inner.dest_hash_hex.clone(), initial_prof);

        // Re-seed default form schemas
        for s in default_form_schemas(&self.inner.dest_hash_hex, &self.inner.nickname.read()) {
            if let Ok(conn) = self.inner.db.lock() {
                let fields_json = serde_json::to_string(&s.fields).unwrap_or_default();
                let _ = conn.execute(
                    "INSERT OR IGNORE INTO form_schemas (id, title, category, description, author_hash, author_nickname, fields_json, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                    rusqlite::params![s.id, s.title, s.category, s.description, s.author_hash, s.author_nickname, fields_json, s.created_at],
                );
            }
            self.inner.form_schemas.write().insert(s.id.clone(), s);
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

            // Sync missing bulletins, file manifests, rooms, schemas, and entries
            let my_b_count = inner.bulletins.read().len();
            let my_f_count = inner.files.read().len();
            let my_r_count = inner.rooms.read().len();
            if is_new || bulletin_count > my_b_count || file_count > my_f_count || room_count > my_r_count {
                let known_b_ids: Vec<String> = inner.bulletins.read().keys().cloned().collect();
                let known_f_hashes: Vec<String> = inner.files.read().keys().cloned().collect();
                let known_r_ids: Vec<String> = inner.rooms.read().keys().cloned().collect();
                let known_s_ids: Vec<String> = inner.form_schemas.read().keys().cloned().collect();
                let known_e_ids: Vec<String> = inner.form_entries.read().values().flat_map(|v| v.iter().map(|e| e.id.clone())).collect();
                let known_p_hashes: Vec<String> = inner.user_profiles.read().keys().cloned().collect();
                let known_m_ids: Vec<String> = inner.markers.read().keys().cloned().collect();
                let sync_req = WireEnvelope::SyncRequest {
                    known_bulletin_ids: known_b_ids,
                    known_file_hashes: known_f_hashes,
                    known_room_ids: known_r_ids,
                    known_schema_ids: known_s_ids,
                    known_entry_ids: known_e_ids,
                    known_profile_hashes: known_p_hashes,
                    known_marker_ids: known_m_ids,
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
                        "INSERT OR IGNORE INTO messages (id, channel, sender_hash, sender_nickname, content, timestamp_sec, audio_base64, audio_duration_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                        rusqlite::params![
                            msg.id,
                            msg.channel,
                            msg.sender_hash,
                            msg.sender_nickname,
                            msg.content,
                            msg.timestamp_sec,
                            msg.audio_base64,
                            msg.audio_duration_sec
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
            known_schema_ids,
            known_entry_ids,
            known_profile_hashes,
            known_marker_ids,
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

            let known_s_set: HashSet<String> = known_schema_ids.into_iter().collect();
            let missing_schemas: Vec<FormSchema> = inner
                .form_schemas
                .read()
                .values()
                .filter(|s| !known_s_set.contains(&s.id))
                .cloned()
                .collect();

            let known_e_set: HashSet<String> = known_entry_ids.into_iter().collect();
            let missing_entries: Vec<FormEntry> = inner
                .form_entries
                .read()
                .values()
                .flat_map(|v| v.iter())
                .filter(|e| !known_e_set.contains(&e.id))
                .cloned()
                .collect();

            let known_p_set: HashSet<String> = known_profile_hashes.into_iter().collect();
            let missing_profiles: Vec<UserProfile> = inner
                .user_profiles
                .read()
                .values()
                .filter(|p| !known_p_set.contains(&p.dest_hash))
                .cloned()
                .collect();

            let known_m_set: HashSet<String> = known_marker_ids.into_iter().collect();
            let missing_markers: Vec<TacticalMarker> = inner
                .markers
                .read()
                .values()
                .filter(|m| !known_m_set.contains(&m.id))
                .cloned()
                .collect();

            if !missing_bulletins.is_empty()
                || !missing_files.is_empty()
                || !missing_rooms.is_empty()
                || !missing_schemas.is_empty()
                || !missing_entries.is_empty()
                || !missing_profiles.is_empty()
                || !missing_markers.is_empty()
            {
                let resp = WireEnvelope::SyncResponse {
                    bulletins: missing_bulletins,
                    files: missing_files,
                    rooms: missing_rooms,
                    schemas: missing_schemas,
                    entries: missing_entries,
                    profiles: missing_profiles,
                    markers: missing_markers,
                };
                if let Ok(json) = serde_json::to_string(&resp) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::SyncResponse {
            bulletins,
            files,
            rooms,
            schemas,
            entries,
            profiles,
            markers,
        } => {
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

            let mut stored_s = inner.form_schemas.write();
            for s in schemas {
                if seen.insert(s.id.clone()) {
                    if let Ok(db) = inner.db.lock() {
                        let fields_json = serde_json::to_string(&s.fields).unwrap_or_default();
                        let _ = db.execute(
                            "INSERT OR IGNORE INTO form_schemas (id, title, category, description, author_hash, author_nickname, fields_json, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                            rusqlite::params![
                                s.id,
                                s.title,
                                s.category,
                                s.description,
                                s.author_hash,
                                s.author_nickname,
                                fields_json,
                                s.created_at
                            ],
                        );
                    }
                    stored_s.insert(s.id.clone(), s);
                }
            }

            let mut stored_e = inner.form_entries.write();
            for e in entries {
                if seen.insert(e.id.clone()) {
                    if let Ok(db) = inner.db.lock() {
                        let _ = db.execute(
                            "INSERT OR IGNORE INTO form_entries (id, schema_id, author_hash, author_nickname, data_json, timestamp_sec, signature_hex) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                            rusqlite::params![
                                e.id,
                                e.schema_id,
                                e.author_hash,
                                e.author_nickname,
                                e.data_json,
                                e.timestamp_sec,
                                e.signature_hex
                            ],
                        );
                    }
                    stored_e.entry(e.schema_id.clone()).or_default().push(e);
                }
            }

            let mut stored_p = inner.user_profiles.write();
            for p in profiles {
                let is_newer = match stored_p.get(&p.dest_hash) {
                    Some(existing) => p.updated_at_sec >= existing.updated_at_sec,
                    None => true,
                };
                if is_newer {
                    if let Ok(db) = inner.db.lock() {
                        let skills_json = serde_json::to_string(&p.skills).unwrap_or_default();
                        let _ = db.execute(
                            "INSERT OR REPLACE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                            rusqlite::params![
                                p.dest_hash,
                                p.nickname,
                                p.bio,
                                p.avatar_base64,
                                p.callsign,
                                p.contact_info,
                                p.neighborhood_zone,
                                skills_json,
                                p.updated_at_sec
                            ],
                        );
                    }
                    if let Some(peer) = inner.peers.write().get_mut(&p.dest_hash) {
                        peer.nickname = p.nickname.clone();
                    }
                    stored_p.insert(p.dest_hash.clone(), p);
                }
            }

            let mut stored_m = inner.markers.write();
            for m in markers {
                if seen.insert(m.id.clone()) {
                    if let Ok(db) = inner.db.lock() {
                        let is_act = if m.is_active { 1 } else { 0 };
                        let _ = db.execute(
                            "INSERT OR REPLACE INTO markers (id, title, category, description, lat, lon, author_hash, author_nickname, author_callsign, timestamp_sec, is_active) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                            rusqlite::params![
                                m.id,
                                m.title,
                                m.category,
                                m.description,
                                m.lat,
                                m.lon,
                                m.author_hash,
                                m.author_nickname,
                                m.author_callsign,
                                m.timestamp_sec,
                                is_act
                            ],
                        );
                    }
                    stored_m.insert(m.id.clone(), m);
                }
            }
        }
        WireEnvelope::ProfileAnnounce(profile) => {
            let mut stored_p = inner.user_profiles.write();
            let is_newer = match stored_p.get(&profile.dest_hash) {
                Some(existing) => profile.updated_at_sec >= existing.updated_at_sec,
                None => true,
            };
            if is_newer {
                if let Ok(db) = inner.db.lock() {
                    let skills_json = serde_json::to_string(&profile.skills).unwrap_or_default();
                    let _ = db.execute(
                        "INSERT OR REPLACE INTO user_profiles (dest_hash, nickname, bio, avatar_base64, callsign, contact_info, neighborhood_zone, skills_json, updated_at_sec) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                        rusqlite::params![
                            profile.dest_hash,
                            profile.nickname,
                            profile.bio,
                            profile.avatar_base64,
                            profile.callsign,
                            profile.contact_info,
                            profile.neighborhood_zone,
                            skills_json,
                            profile.updated_at_sec
                        ],
                    );
                }
                if let Some(peer) = inner.peers.write().get_mut(&profile.dest_hash) {
                    peer.nickname = profile.nickname.clone();
                }
                stored_p.insert(profile.dest_hash.clone(), profile);
            }
        }
        WireEnvelope::ProfileRequest { dest_hash } => {
            let stored_p = inner.user_profiles.read();
            if let Some(prof) = stored_p.get(&dest_hash) {
                let resp = WireEnvelope::ProfileAnnounce(prof.clone());
                if let Ok(json) = serde_json::to_string(&resp) {
                    let _ = socket.send_to(json.as_bytes(), src);
                }
            }
        }
        WireEnvelope::FormSchemaAnnounce(schema) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(schema.id.clone()) {
                if let Ok(db) = inner.db.lock() {
                    let fields_json = serde_json::to_string(&schema.fields).unwrap_or_default();
                    let _ = db.execute(
                        "INSERT OR IGNORE INTO form_schemas (id, title, category, description, author_hash, author_nickname, fields_json, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                        rusqlite::params![
                            schema.id,
                            schema.title,
                            schema.category,
                            schema.description,
                            schema.author_hash,
                            schema.author_nickname,
                            fields_json,
                            schema.created_at
                        ],
                    );
                }
                inner.form_schemas.write().insert(schema.id.clone(), schema);
            }
        }
        WireEnvelope::FormEntryAnnounce(entry) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(entry.id.clone()) {
                if let Ok(db) = inner.db.lock() {
                    let _ = db.execute(
                        "INSERT OR IGNORE INTO form_entries (id, schema_id, author_hash, author_nickname, data_json, timestamp_sec, signature_hex) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                        rusqlite::params![
                            entry.id,
                            entry.schema_id,
                            entry.author_hash,
                            entry.author_nickname,
                            entry.data_json,
                            entry.timestamp_sec,
                            entry.signature_hex
                        ],
                    );
                }
                inner.form_entries.write().entry(entry.schema_id.clone()).or_default().push(entry);
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
        WireEnvelope::PttVoice(_chunk) => {
            // PTT voice chunks are broadcast live across the mesh
        }
        WireEnvelope::PttFloor(_signal) => {
            // PTT floor signals are processed by clients
        }
        WireEnvelope::MarkerAnnounce(marker) => {
            let mut seen = inner.seen_ids.write();
            if seen.insert(marker.id.clone()) {
                if let Ok(db) = inner.db.lock() {
                    let is_act = if marker.is_active { 1 } else { 0 };
                    let _ = db.execute(
                        "INSERT OR REPLACE INTO markers (id, title, category, description, lat, lon, author_hash, author_nickname, author_callsign, timestamp_sec, is_active) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                        rusqlite::params![
                            marker.id,
                            marker.title,
                            marker.category,
                            marker.description,
                            marker.lat,
                            marker.lon,
                            marker.author_hash,
                            marker.author_nickname,
                            marker.author_callsign,
                            marker.timestamp_sec,
                            is_act
                        ],
                    );
                }
                inner.markers.write().insert(marker.id.clone(), marker);
            }
        }
        WireEnvelope::MarkerDelete(marker_id) => {
            inner.markers.write().remove(&marker_id);
            if let Ok(db) = inner.db.lock() {
                let _ = db.execute("DELETE FROM markers WHERE id = ?1", rusqlite::params![marker_id]);
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

// --- OFFLINE FORMS & COMMUNITY LEDGER FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_get_form_schemas_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let schemas = node.get_form_schemas();
    let json = serde_json::to_string(&schemas).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_create_form_schema(
    title_c: *const c_char,
    description_c: *const c_char,
    category_c: *const c_char,
    fields_json_c: *const c_char,
) -> *mut c_char {
    if title_c.is_null() || description_c.is_null() || category_c.is_null() || fields_json_c.is_null() {
        return to_c_string("{\"error\":\"Invalid arguments\"}".to_string());
    }
    let title = unsafe { CStr::from_ptr(title_c).to_string_lossy().into_owned() };
    let description = unsafe { CStr::from_ptr(description_c).to_string_lossy().into_owned() };
    let category = unsafe { CStr::from_ptr(category_c).to_string_lossy().into_owned() };
    let fields_json = unsafe { CStr::from_ptr(fields_json_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("{\"error\":\"Node not initialized\"}".to_string()),
    };

    let fields: Vec<FormFieldDef> = serde_json::from_str(&fields_json).unwrap_or_default();
    match node.create_form_schema(title, description, category, fields) {
        Ok(schema) => {
            let json = serde_json::to_string(&schema).unwrap_or_else(|_| "{}".to_string());
            to_c_string(json)
        }
        Err(e) => {
            let json = serde_json::json!({ "error": e }).to_string();
            to_c_string(json)
        }
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_form_entries_json(schema_id_c: *const c_char) -> *mut c_char {
    if schema_id_c.is_null() {
        return to_c_string("[]".to_string());
    }
    let schema_id = unsafe { CStr::from_ptr(schema_id_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let entries = node.get_form_entries(&schema_id);
    let json = serde_json::to_string(&entries).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_submit_form_entry(
    schema_id_c: *const c_char,
    data_json_c: *const c_char,
) -> *mut c_char {
    if schema_id_c.is_null() || data_json_c.is_null() {
        return to_c_string("{\"error\":\"Invalid arguments\"}".to_string());
    }
    let schema_id = unsafe { CStr::from_ptr(schema_id_c).to_string_lossy().into_owned() };
    let data_json = unsafe { CStr::from_ptr(data_json_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("{\"error\":\"Node not initialized\"}".to_string()),
    };

    match node.submit_form_entry(schema_id, data_json) {
        Ok(entry) => {
            let json = serde_json::to_string(&entry).unwrap_or_else(|_| "{}".to_string());
            to_c_string(json)
        }
        Err(e) => {
            let json = serde_json::json!({ "error": e }).to_string();
            to_c_string(json)
        }
    }
}



// --- SOVEREIGN PROFILES & TACTICAL ID FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_get_my_profile_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("{}".to_string()),
    };

    let prof = node.get_my_profile();
    let json = serde_json::to_string(&prof).unwrap_or_else(|_| "{}".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_update_my_profile(profile_json_c: *const c_char) -> *mut c_char {
    if profile_json_c.is_null() {
        return to_c_string("{\"error\":\"Invalid profile JSON pointer\"}".to_string());
    }
    let profile_json = unsafe { CStr::from_ptr(profile_json_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("{\"error\":\"Node not initialized\"}".to_string()),
    };

    let profile: UserProfile = match serde_json::from_str(&profile_json) {
        Ok(p) => p,
        Err(e) => return to_c_string(format!("{{\"error\":\"Invalid JSON schema: {e}\"}}")),
    };

    match node.update_my_profile(profile) {
        Ok(saved) => {
            let json = serde_json::to_string(&saved).unwrap_or_else(|_| "{}".to_string());
            to_c_string(json)
        }
        Err(e) => {
            let json = serde_json::json!({ "error": e }).to_string();
            to_c_string(json)
        }
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_peer_profile_json(dest_hash_c: *const c_char) -> *mut c_char {
    if dest_hash_c.is_null() {
        return to_c_string("null".to_string());
    }
    let dest_hash = unsafe { CStr::from_ptr(dest_hash_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("null".to_string()),
    };

    match node.get_peer_profile(&dest_hash) {
        Some(p) => {
            let json = serde_json::to_string(&p).unwrap_or_else(|_| "null".to_string());
            to_c_string(json)
        }
        None => to_c_string("null".to_string()),
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_get_all_profiles_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let list = node.get_all_profiles();
    let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

// --- PUSH-TO-TALK (PTT) TACTICAL WALKIE-TALKIE FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_send_ptt_chunk(
    session_id_c: *const c_char,
    sequence: u32,
    channel_c: *const c_char,
    audio_base64_c: *const c_char,
    is_final: bool,
    priority_c: *const c_char,
) -> bool {
    if session_id_c.is_null() || channel_c.is_null() || audio_base64_c.is_null() {
        return false;
    }
    let session_id = unsafe { CStr::from_ptr(session_id_c).to_string_lossy().into_owned() };
    let channel = unsafe { CStr::from_ptr(channel_c).to_string_lossy().into_owned() };
    let audio_base64 = unsafe { CStr::from_ptr(audio_base64_c).to_string_lossy().into_owned() };
    let priority = if priority_c.is_null() {
        "normal".to_string()
    } else {
        unsafe { CStr::from_ptr(priority_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    let profile = node.get_my_profile();
    let chunk = PttVoiceChunk {
        session_id,
        sequence,
        channel,
        sender_hash: profile.dest_hash,
        sender_nickname: profile.nickname,
        sender_callsign: profile.callsign,
        audio_base64,
        is_final,
        priority,
        timestamp_sec: current_epoch_sec(),
    };

    node.send_ptt_chunk(chunk);
    true
}

#[no_mangle]
pub extern "C" fn neighbornet_send_ptt_floor(
    channel_c: *const c_char,
    is_transmitting: bool,
    priority_c: *const c_char,
) -> bool {
    if channel_c.is_null() {
        return false;
    }
    let channel = unsafe { CStr::from_ptr(channel_c).to_string_lossy().into_owned() };
    let priority = if priority_c.is_null() {
        "normal".to_string()
    } else {
        unsafe { CStr::from_ptr(priority_c).to_string_lossy().into_owned() }
    };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    let profile = node.get_my_profile();
    let signal = PttFloorSignal {
        channel,
        speaker_hash: profile.dest_hash,
        speaker_nickname: profile.nickname,
        speaker_callsign: profile.callsign,
        is_transmitting,
        priority,
        timestamp_sec: current_epoch_sec(),
    };

    node.send_ptt_floor(signal);
    true
}

// --- VOICE MEMO & TACTICAL MAP FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn neighbornet_send_voice_chat(
    channel_c: *const c_char,
    content_c: *const c_char,
    audio_base64_c: *const c_char,
    audio_duration_sec: u32,
) -> bool {
    if channel_c.is_null() || content_c.is_null() {
        return false;
    }
    let channel = unsafe { CStr::from_ptr(channel_c).to_string_lossy().into_owned() };
    let content = unsafe { CStr::from_ptr(content_c).to_string_lossy().into_owned() };
    let audio_base64 = if audio_base64_c.is_null() {
        None
    } else {
        Some(unsafe { CStr::from_ptr(audio_base64_c).to_string_lossy().into_owned() })
    };
    let duration = if audio_duration_sec > 0 { Some(audio_duration_sec) } else { None };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.send_voice_chat(channel, content, audio_base64, duration);
    true
}

#[no_mangle]
pub extern "C" fn neighbornet_get_markers_json() -> *mut c_char {
    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("[]".to_string()),
    };

    let list = node.get_markers();
    let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn neighbornet_upsert_marker(marker_json_c: *const c_char) -> *mut c_char {
    if marker_json_c.is_null() {
        return to_c_string("{\"error\":\"Invalid marker JSON pointer\"}".to_string());
    }
    let marker_json = unsafe { CStr::from_ptr(marker_json_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return to_c_string("{\"error\":\"Node not initialized\"}".to_string()),
    };

    let marker: TacticalMarker = match serde_json::from_str(&marker_json) {
        Ok(m) => m,
        Err(e) => return to_c_string(format!("{{\"error\":\"Invalid JSON schema: {e}\"}}")),
    };

    match node.upsert_marker(marker) {
        Ok(saved) => {
            let json = serde_json::to_string(&saved).unwrap_or_else(|_| "{}".to_string());
            to_c_string(json)
        }
        Err(e) => {
            let json = serde_json::json!({ "error": e }).to_string();
            to_c_string(json)
        }
    }
}

#[no_mangle]
pub extern "C" fn neighbornet_delete_marker(marker_id_c: *const c_char) -> bool {
    if marker_id_c.is_null() {
        return false;
    }
    let marker_id = unsafe { CStr::from_ptr(marker_id_c).to_string_lossy().into_owned() };

    let lock = GLOBAL_NODE.read();
    let node = match lock.as_ref() {
        Some(n) => n,
        None => return false,
    };

    node.delete_marker(&marker_id)
}

