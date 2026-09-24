use neighbornet_core::NeighborNode;
use tempfile::tempdir;

#[test]
fn test_emergency_panic_wipe_shredder() {
    let dir = tempdir().unwrap();
    let data_dir = dir.path().to_path_buf();

    // Create a node
    let node = NeighborNode::new(data_dir.clone(), 49911, false).expect("Create node");

    // Insert dummy chat messages and bulletins
    node.send_chat("general".to_string(), "Top secret survival coordinate".to_string());
    node.post_bulletin("ALERT".to_string(), "Critical warning".to_string(), "EMERGENCY".to_string());

    // Verify identity.hex exists
    let id_path = data_dir.join("identity.hex");
    assert!(id_path.exists(), "Identity file must exist initially");

    // Execute Panic Wipe
    let result = node.panic_wipe();
    assert!(result.is_ok(), "Panic wipe execution must succeed");

    // Verify identity file is deleted / shredded
    assert!(!id_path.exists(), "Identity file must be deleted after panic wipe");

    // Verify messages and bulletins are purged from in-memory and SQLite
    let msgs = node.get_chat_history("general");
    assert_eq!(msgs.len(), 0, "Chat history must be empty after panic wipe");

    let bulletins = node.get_bulletins();
    assert_eq!(bulletins.len(), 0, "Bulletins must be empty after panic wipe");

    node.stop();
}
