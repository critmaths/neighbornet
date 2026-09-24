use neighbornet_core::NeighborNode;
use tempfile::tempdir;

#[test]
fn test_emergency_panic_wipe_shredder() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    node.send_chat("emergency".to_string(), "Top secret survival coord".to_string());
    node.post_bulletin("DEFCON".to_string(), "Immediate evacuation".to_string(), "emergency".to_string());

    assert_eq!(node.get_chat_history("emergency").len(), 1);
    assert_eq!(node.get_bulletins().len(), 1);

    // Execute Panic Wipe
    node.panic_wipe().unwrap();

    assert_eq!(node.get_chat_history("emergency").len(), 0);
    assert_eq!(node.get_bulletins().len(), 0);
    assert_eq!(node.get_rooms().len(), 0);
    assert_eq!(node.get_shared_files().len(), 0);
}
