use neighbornet_core::{NeighborNode, TacticalMarker};
use tempfile::tempdir;

#[test]
fn test_tactical_marker_lifecycle_and_persistence() {
    let dir = tempdir().unwrap();
    let data_dir = dir.path().to_path_buf();

    // 1. Initialize node
    let node = NeighborNode::new(data_dir.clone(), 0, false).expect("Node creation failed");

    // 2. Add tactical markers
    let marker1 = TacticalMarker {
        id: String::new(),
        title: "Triage Alpha".to_string(),
        category: "medical".to_string(),
        description: "Field medic station with first aid supplies.".to_string(),
        lat: 34.0522,
        lon: -118.2437,
        author_hash: String::new(),
        author_nickname: String::new(),
        author_callsign: String::new(),
        timestamp_sec: 0,
        is_active: true,
    };

    let marker2 = TacticalMarker {
        id: String::new(),
        title: "Clean Water Well".to_string(),
        category: "water".to_string(),
        description: "Gravity fed potable water source.".to_string(),
        lat: 34.0535,
        lon: -118.2420,
        author_hash: String::new(),
        author_nickname: String::new(),
        author_callsign: String::new(),
        timestamp_sec: 0,
        is_active: true,
    };

    let saved1 = node.upsert_marker(marker1).expect("Failed to upsert marker 1");
    let _saved2 = node.upsert_marker(marker2).expect("Failed to upsert marker 2");

    assert!(!saved1.id.is_empty());
    assert_eq!(saved1.title, "Triage Alpha");
    assert_eq!(saved1.category, "medical");

    let markers = node.get_markers();
    assert_eq!(markers.len(), 2);

    // 3. Stop node and restart to test SQLite reload
    node.stop();
    drop(node);

    let node2 = NeighborNode::new(data_dir.clone(), 0, false).expect("Restart node failed");
    let reloaded = node2.get_markers();
    assert_eq!(reloaded.len(), 2);

    let found_alpha = reloaded.iter().find(|m| m.title == "Triage Alpha").unwrap();
    assert_eq!(found_alpha.category, "medical");
    assert!((found_alpha.lat - 34.0522).abs() < 0.0001);

    // 4. Delete marker
    let deleted = node2.delete_marker(&saved1.id);
    assert!(deleted);
    let after_delete = node2.get_markers();
    assert_eq!(after_delete.len(), 1);
    assert_eq!(after_delete[0].title, "Clean Water Well");

    node2.stop();
}

#[test]
fn test_voice_chat_persistence() {
    let dir = tempdir().unwrap();
    let data_dir = dir.path().to_path_buf();

    let node = NeighborNode::new(data_dir.clone(), 0, false).expect("Node creation failed");

    // Send voice memo in chat
    let fake_audio_b64 = "UklGRi4AAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=".to_string();
    let msg_id = node.send_voice_chat(
        "emergency".to_string(),
        "Voice memo (3s)".to_string(),
        Some(fake_audio_b64.clone()),
        Some(3),
    );

    assert!(!msg_id.is_empty());

    let history = node.get_chat_history("emergency");
    assert_eq!(history.len(), 1);
    assert_eq!(history[0].audio_base64.as_deref(), Some(fake_audio_b64.as_str()));
    assert_eq!(history[0].audio_duration_sec, Some(3));

    // Restart and verify SQLite reload
    node.stop();
    drop(node);

    let node2 = NeighborNode::new(data_dir, 0, false).expect("Restart node failed");
    let history2 = node2.get_chat_history("emergency");
    assert_eq!(history2.len(), 1);
    assert_eq!(history2[0].audio_base64.as_deref(), Some(fake_audio_b64.as_str()));
    assert_eq!(history2[0].audio_duration_sec, Some(3));

    node2.stop();
}
