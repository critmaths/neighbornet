use neighbornet_core::{NeighborNode, PttFloorSignal, PttVoiceChunk};
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU16, Ordering};

static PORT_COUNTER: AtomicU16 = AtomicU16::new(43500);

fn next_port() -> u16 {
    PORT_COUNTER.fetch_add(1, Ordering::SeqCst)
}

fn create_temp_node(prefix: &str) -> (NeighborNode, PathBuf) {
    let port = next_port();
    let data_dir = std::env::temp_dir().join(format!("neighbornet_ptt_test_{}_{}", prefix, port));
    let _ = fs::remove_dir_all(&data_dir);
    fs::create_dir_all(&data_dir).unwrap();

    let node = NeighborNode::new(data_dir.clone(), port, false).unwrap();
    (node, data_dir)
}

#[test]
fn test_ptt_floor_and_voice_chunk_broadcast() {
    let (node_a, dir_a) = create_temp_node("node_a");
    let (node_b, dir_b) = create_temp_node("node_b");

    let port_b = node_b.inner.listen_port;
    node_a.connect_peer(format!("127.0.0.1:{}", port_b).parse().unwrap());
    std::thread::sleep(std::time::Duration::from_millis(200));

    // Broadcast floor claim on CH-01
    let floor_signal = PttFloorSignal {
        channel: "CH-01".to_string(),
        speaker_hash: node_a.inner.dest_hash_hex.clone(),
        speaker_nickname: "Alice-Radio".to_string(),
        speaker_callsign: "AL-01".to_string(),
        is_transmitting: true,
        priority: "normal".to_string(),
        timestamp_sec: 1720000000,
    };
    node_a.send_ptt_floor(floor_signal);

    // Broadcast audio voice chunk
    let chunk = PttVoiceChunk {
        session_id: "test_tx_001".to_string(),
        sequence: 1,
        channel: "CH-01".to_string(),
        sender_hash: node_a.inner.dest_hash_hex.clone(),
        sender_nickname: "Alice-Radio".to_string(),
        sender_callsign: "AL-01".to_string(),
        audio_base64: "SGVsbG8gV29ybGQgUFRUIEF1ZGlv".to_string(),
        is_final: false,
        priority: "normal".to_string(),
        timestamp_sec: 1720000001,
    };
    node_a.send_ptt_chunk(chunk);

    // Broadcast final chunk
    let chunk_final = PttVoiceChunk {
        session_id: "test_tx_001".to_string(),
        sequence: 2,
        channel: "CH-01".to_string(),
        sender_hash: node_a.inner.dest_hash_hex.clone(),
        sender_nickname: "Alice-Radio".to_string(),
        sender_callsign: "AL-01".to_string(),
        audio_base64: "T3ZlciBhbmQgb3V0".to_string(),
        is_final: true,
        priority: "normal".to_string(),
        timestamp_sec: 1720000002,
    };
    node_a.send_ptt_chunk(chunk_final);

    // Broadcast floor release
    let floor_release = PttFloorSignal {
        channel: "CH-01".to_string(),
        speaker_hash: node_a.inner.dest_hash_hex.clone(),
        speaker_nickname: "Alice-Radio".to_string(),
        speaker_callsign: "AL-01".to_string(),
        is_transmitting: false,
        priority: "normal".to_string(),
        timestamp_sec: 1720000003,
    };
    node_a.send_ptt_floor(floor_release);

    std::thread::sleep(std::time::Duration::from_millis(200));

    node_a.stop();
    node_b.stop();
    let _ = fs::remove_dir_all(dir_a);
    let _ = fs::remove_dir_all(dir_b);
}
