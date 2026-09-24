use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

#[test]
fn test_democratic_room_stewardship_and_audit_trail() {
    println!("\n=== RUNNING DEMOCRATIC STEWARDSHIP & AUDIT LOG TEST ===");

    let dir_a = tempfile::tempdir().unwrap();
    let dir_b = tempfile::tempdir().unwrap();
    let dir_c = tempfile::tempdir().unwrap();

    // 1. Launch 3 Nodes: Alice (47110), Bob (47120), Charlie (47130)
    println!("Step 1: Starting Alice (47110), Bob (47120), Charlie (47130)...");
    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), 47110, false).unwrap();
    node_a.set_nickname("Alice Organizer".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), 47120, false).unwrap();
    node_b.set_nickname("Bob Member".to_string());

    let node_c = NeighborNode::new(dir_c.path().to_path_buf(), 47130, false).unwrap();
    node_c.set_nickname("Charlie Elder".to_string());

    node_a.connect_peer("127.0.0.1:47120".parse().unwrap());
    node_a.connect_peer("127.0.0.1:47130".parse().unwrap());
    node_b.connect_peer("127.0.0.1:47110".parse().unwrap());
    node_b.connect_peer("127.0.0.1:47130".parse().unwrap());
    node_c.connect_peer("127.0.0.1:47110".parse().unwrap());
    node_c.connect_peer("127.0.0.1:47120".parse().unwrap());

    thread::sleep(Duration::from_millis(500));

    // 2. Alice creates a custom room: #water-station
    println!("Step 2: Alice creates custom room '#water-station'...");
    let room = node_a.create_room(
        "water-station".to_string(),
        "Community clean water distribution and filtration schedule".to_string(),
        false,
    );
    assert_eq!(room.name, "water-station");
    assert_eq!(room.stewards.len(), 1);
    assert_eq!(room.stewards[0], node_a.inner.dest_hash_hex);
    println!("  Room created with ID: {}", room.id);
    println!("  Genesis Steward: Alice ({})", node_a.inner.dest_hash_hex);

    // 3. Wait for Bob and Charlie to discover room
    println!("Step 3: Waiting for Bob and Charlie to discover room announcement...");
    let mut discovered = false;
    for _ in 0..10 {
        thread::sleep(Duration::from_millis(200));
        let rooms_on_b = node_b.get_rooms();
        if rooms_on_b.iter().any(|r| r.id == room.id) {
            discovered = true;
            println!("  [SUCCESS] Bob discovered room: \"{}\"", rooms_on_b[0].name);
            break;
        }
    }
    assert!(discovered, "Bob failed to receive room announcement");

    // 4. Alice proposes promoting Bob as co-steward
    println!("Step 4: Alice proposes promoting Bob to co-steward...");
    let prop_promote = node_a
        .propose_steward_vote(
            room.id.clone(),
            node_b.inner.dest_hash_hex.clone(),
            "Bob Member".to_string(),
            "promote".to_string(),
            "Community Support".to_string(),
            "Willing to manage daily tank refills".to_string(),
        )
        .expect("Failed to create promotion proposal");

    // Charlie waits for proposal to arrive and casts affirmative vote for Bob
    println!("Step 5: Charlie casts affirmative vote for Bob's promotion...");
    let mut vote_cast = false;
    for _ in 0..25 {
        thread::sleep(Duration::from_millis(150));
        if node_c.cast_vote(&prop_promote, true) {
            vote_cast = true;
            break;
        }
    }
    assert!(vote_cast, "Charlie was unable to cast vote for proposal");

    // Also cast on Alice's node and poll for quorum evaluation across nodes
    let mut bob_promoted = false;
    for _ in 0..25 {
        node_a.cast_vote(&prop_promote, true);
        thread::sleep(Duration::from_millis(150));
        let rooms_a = node_a.get_rooms();
        if let Some(updated_room) = rooms_a.iter().find(|r| r.id == room.id) {
            if updated_room.stewards.contains(&node_b.inner.dest_hash_hex) {
                bob_promoted = true;
                println!("  [SUCCESS] Bob is now an active Steward: {:?}", updated_room.stewards);
                break;
            }
        }
    }
    assert!(bob_promoted, "Bob was not added to stewards list after quorum vote!");

    // 5. Demotion scenario: Bob acts disruptively. Alice proposes demoting Bob with public reason
    println!("Step 6: Alice proposes demoting Bob with reason 'Spam / Disruption'...");
    let prop_demote = node_a
        .propose_steward_vote(
            room.id.clone(),
            node_b.inner.dest_hash_hex.clone(),
            "Bob Member".to_string(),
            "demote".to_string(),
            "Spam / Disruption".to_string(),
            "Flooding channel with off-topic noise during supply distribution".to_string(),
        )
        .expect("Failed to create demotion proposal");

    // Charlie waits for proposal and votes to approve demotion
    println!("Step 7: Charlie votes FOR demotion...");
    let mut demote_cast = false;
    for _ in 0..25 {
        thread::sleep(Duration::from_millis(150));
        if node_c.cast_vote(&prop_demote, true) {
            demote_cast = true;
            break;
        }
    }
    assert!(demote_cast, "Charlie was unable to cast demotion vote");

    // Poll for demotion quorum completion
    let mut bob_demoted = false;
    for _ in 0..25 {
        node_a.cast_vote(&prop_demote, true);
        thread::sleep(Duration::from_millis(150));
        let rooms_after_demote = node_a.get_rooms();
        if let Some(demoted_room) = rooms_after_demote.iter().find(|r| r.id == room.id) {
            if !demoted_room.stewards.contains(&node_b.inner.dest_hash_hex) {
                bob_demoted = true;
                println!("  [SUCCESS] Bob was democratically demoted! Current stewards: {:?}", demoted_room.stewards);
                break;
            }
        }
    }
    assert!(bob_demoted, "Bob should have been removed from stewards!");

    // 7. Verify Transparent Audit Log
    println!("Step 8: Verifying public cryptographic audit log...");
    let audit_events = node_a.get_audit_log(&room.id);
    assert!(!audit_events.is_empty(), "Audit log should contain recorded events");
    println!("  Recorded Audit Events: {}", audit_events.len());
    for ev in &audit_events {
        println!("  ⚖️ EVENT: {}", ev.summary);
        println!("     REASON: {}", ev.reason);
    }

    let demote_event = audit_events.iter().find(|e| e.summary.contains("demoted"));
    assert!(demote_event.is_some(), "Expected demotion event in audit log");
    assert!(demote_event.unwrap().reason.contains("Spam / Disruption"));

    node_a.stop();
    node_b.stop();
    node_c.stop();
    println!("=== DEMOCRATIC GOVERNANCE & AUDIT TRAIL TEST PASSED 100% ===\n");
}
