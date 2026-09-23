use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

#[test]
fn test_multi_node_store_and_forward_partition_sync() {
    println!("\n=== RUNNING MULTI-NODE PARTITION & STORE-AND-FORWARD TEST ===");

    let dir_a = tempfile::tempdir().unwrap();
    let dir_b = tempfile::tempdir().unwrap();
    let dir_c = tempfile::tempdir().unwrap();

    // 1. Start Node A (Alice, Leaf Node) and Node B (Community Relay Hub)
    println!("Step 1: Launching Node A (Alice) on port 45110 and Node B (Relay Pi) on port 45120...");
    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), 45110, false).unwrap();
    node_a.set_nickname("Alice Phone".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), 45120, true).unwrap();
    node_b.set_nickname("Civic Center Pi".to_string());

    node_a.connect_peer("127.0.0.1:45120".parse().unwrap());

    // 2. Alice posts an urgent bulletin on Node A
    println!("Step 2: Alice posts urgent bulletin on Node A...");
    let notice_id = node_a.post_bulletin(
        "Medical Supplies Needed at Clinic".to_string(),
        "Sterile gauze and insulin refrigeration needed.".to_string(),
        "urgent".to_string(),
    );
    assert!(!notice_id.is_empty());

    // 3. Allow periodic UDP announcements and opportunistic sync between A and B
    println!("Step 3: Waiting for mutual discovery and sync between A and B...");
    let mut b_received = false;
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(500));
        let bulletins_on_b = node_b.get_bulletins();
        if bulletins_on_b.iter().any(|b| b.id == notice_id) {
            b_received = true;
            println!("  [SUCCESS] Node B synced notice: \"{}\"", bulletins_on_b[0].title);
            break;
        }
    }
    assert!(b_received, "Node B failed to sync bulletin from Node A");

    // 4. Partition / Disconnect: Alice goes offline!
    println!("Step 4: Simulating Network Partition: Alice shuts down and goes offline...");
    node_a.stop();
    drop(node_a);
    thread::sleep(Duration::from_millis(500));

    // 5. Node C (Bob) comes online later. Bob has NEVER seen or connected to Alice.
    println!("Step 5: Bob launches Node C on port 45130 (Alice is offline)...");
    let node_c = NeighborNode::new(dir_c.path().to_path_buf(), 45130, false).unwrap();
    node_c.set_nickname("Bob Laptop".to_string());
    node_c.connect_peer("127.0.0.1:45120".parse().unwrap());

    // 6. Bob discovers Relay Node B. Relay Node B should opportunistically forward Alice's notice to Bob!
    println!("Step 6: Waiting for Bob to discover Relay B and sync Alice's offline notice...");
    let mut c_received = false;
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(500));
        let bulletins_on_c = node_c.get_bulletins();
        if bulletins_on_c.iter().any(|b| b.id == notice_id) {
            c_received = true;
            println!("  [SUCCESS] Bob (Node C) received Alice's notice from Relay B while Alice is offline!");
            println!("  Notice Title: {}", bulletins_on_c[0].title);
            println!("  Author: {} ({})", bulletins_on_c[0].author_nickname, bulletins_on_c[0].author_hash);
            break;
        }
    }
    assert!(c_received, "Node C failed to receive store-and-forward bulletin from Relay B");

    // 7. Clean up
    node_b.stop();
    node_c.stop();
    println!("=== TEST COMPLETED SUCCESSFULLY WITH 100% REAL SOCKET ROUTING ===");
}
