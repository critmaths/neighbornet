use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

#[test]
fn test_room_deduplication_and_mesh_deletion() {
    println!("\n=== RUNNING ROOM DEDUPLICATION AND MESH DELETION TEST ===");

    let dir_a = tempfile::tempdir().unwrap();
    let dir_b = tempfile::tempdir().unwrap();

    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), 0, false).unwrap();
    node_a.set_nickname("Alice".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), 0, false).unwrap();
    node_b.set_nickname("Bob".to_string());

    let port_a = node_a.get_status().listen_port;
    let port_b = node_b.get_status().listen_port;
    println!("Alice port: {}, Bob port: {}", port_a, port_b);

    node_a.connect_peer(format!("127.0.0.1:{}", port_b).parse().unwrap());
    node_b.connect_peer(format!("127.0.0.1:{}", port_a).parse().unwrap());

    thread::sleep(Duration::from_millis(500));

    // 1. Create a room
    let room1 = node_a.create_room("radio-club".to_string(), "Ham radio operators".to_string(), false);
    assert_eq!(room1.name, "radio-club");

    // 2. Try creating duplicate room with same name (case-insensitive)
    let room_dup = node_a.create_room("RADIO-CLUB".to_string(), "Duplicate attempt".to_string(), false);
    assert_eq!(room_dup.id, room1.id, "Duplicate creation should return existing room");

    let rooms_a = node_a.get_rooms();
    assert_eq!(rooms_a.len(), 1, "Should only have 1 room, not duplicate");

    // 3. Verify Bob syncs the room
    let mut bob_has_room = false;
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(200));
        let rooms_b = node_b.get_rooms();
        if rooms_b.iter().any(|r| r.id == room1.id) {
            bob_has_room = true;
            break;
        }
    }
    assert!(bob_has_room, "Bob should discover room1");

    // 4. Bob creates a message in room1
    node_b.send_chat(room1.id.clone(), "Hello radio enthusiasts!".to_string());
    thread::sleep(Duration::from_millis(300));
    let msgs_b = node_b.get_chat_history(&room1.id);
    assert!(!msgs_b.is_empty(), "Bob should have message in room");

    // 5. Delete room on Alice's node
    println!("Deleting room on Alice's node...");
    let deleted = node_a.delete_room(&room1.id);
    assert!(deleted, "delete_room should return true");
    assert_eq!(node_a.get_rooms().len(), 0, "Alice should have 0 rooms after deletion");

    // 6. Verify Bob receives the RoomDelete envelope and removes the room & chat history
    let mut bob_deleted = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(200));
        if node_b.get_rooms().is_empty() {
            bob_deleted = true;
            break;
        }
    }
    assert!(bob_deleted, "Bob should have deleted the room after receiving RoomDelete broadcast");
    let msgs_b_after = node_b.get_chat_history(&room1.id);
    assert!(msgs_b_after.is_empty(), "Bob chat history for deleted room should be purged");

    node_a.stop();
    node_b.stop();
    println!("=== ROOM DEDUPLICATION AND MESH DELETION TEST PASSED ===\n");
}
