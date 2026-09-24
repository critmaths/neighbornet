use neighbornet_core::NeighborNode;

#[test]
fn test_emergency_panic_wipe_shredder() {
    println!("\n=== RUNNING EMERGENCY PANIC WIPE SHREDDER TEST ===");

    let temp_dir = tempfile::tempdir().unwrap();
    let data_path = temp_dir.path().to_path_buf();

    // 1. Initialize node and create messages, bulletins, rooms, files
    let node = NeighborNode::new(data_path.clone(), 49110, false).unwrap();
    node.set_nickname("Agent Zero".to_string());

    // Create room
    let room = node.create_room("tactical-operations".to_string(), "Top secret channel".to_string(), true);
    assert_eq!(room.name, "tactical-operations");

    // Post bulletin
    let bulletin_id = node.post_bulletin(
        "Bridge Out Sector 7".to_string(),
        "Avoid highway intersection due to structural damage".to_string(),
        "critical".to_string(),
    );
    assert!(!bulletin_id.is_empty());

    // Send chat
    let chat_id = node.send_chat("tactical-operations".to_string(), "Classified rendezvous coordinates: 32.7767, -96.7970".to_string());
    assert!(!chat_id.is_empty());

    // Verify data exists on disk
    let identity_file = data_path.join("identity.hex");
    let db_file = data_path.join("neighbornet.db");
    let room_file = data_path.join("rooms").join(format!("{}.json", room.id));

    assert!(identity_file.exists(), "identity.hex should exist");
    assert!(db_file.exists(), "neighbornet.db should exist");
    assert!(room_file.exists(), "room json should exist");

    // 2. Trigger Emergency Panic Wipe
    println!("Triggering panic_wipe()...");
    let wipe_result = node.panic_wipe();
    assert!(wipe_result.is_ok(), "Panic wipe should execute successfully");

    // 3. Verify sensitive state is obliterated
    assert!(!identity_file.exists(), "identity.hex must be unlinked/deleted");
    assert!(!room_file.exists(), "room file must be deleted");
    assert_eq!(node.get_rooms().len(), 0, "In-memory rooms must be empty");
    assert_eq!(node.get_bulletins().len(), 0, "In-memory bulletins must be empty");
    assert_eq!(node.get_chat_history("tactical-operations").len(), 0, "Chat history must be empty");

    // Verify nickname was reset to fresh anonymous identity
    let status = node.get_status();
    assert!(status.nickname.starts_with("Neighbor-"), "Nickname should reset to anonymous Neighbor-XXXX");

    node.stop();
    println!("=== EMERGENCY PANIC WIPE TEST PASSED 100% ===\n");
}
