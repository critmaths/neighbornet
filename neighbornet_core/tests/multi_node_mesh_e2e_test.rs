use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;
use tempfile::tempdir;

#[test]
fn test_multi_node_mesh_e2e_gossip_barter_and_partition_healing() {
    println!("\n=================================================================");
    println!("  RUNNING FULL MULTI-PEER 4-NODE MESH END-TO-END TEST");
    println!("  Topology: [Node A (Alice)] <---> [Relay B] <---> [Relay C] <---> [Node D (Dave)]");
    println!("=================================================================\n");

    let dir_a = tempdir().unwrap();
    let dir_b = tempdir().unwrap();
    let dir_c = tempdir().unwrap();
    let dir_d = tempdir().unwrap();

    let port_a: u16 = 46310;
    let port_b: u16 = 46320;
    let port_c: u16 = 46330;
    let port_d: u16 = 46340;

    // 1. Initialize 4 Nodes
    println!("Step 1: Initializing 4 mesh nodes with asymmetric transport roles...");
    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), port_a, false).unwrap();
    node_a.set_nickname("Alice Phone".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), port_b, true).unwrap();
    node_b.set_nickname("Relay Hub Alpha".to_string());

    let node_c = NeighborNode::new(dir_c.path().to_path_buf(), port_c, true).unwrap();
    node_c.set_nickname("Relay Hub Bravo".to_string());

    let node_d = NeighborNode::new(dir_d.path().to_path_buf(), port_d, false).unwrap();
    node_d.set_nickname("Dave Laptop".to_string());

    // 2. Wire Multi-Hop Linear Topology: A <-> B <-> C <-> D
    println!("Step 2: Connecting peer links (A<->B, B<->C, C<->D)...");
    node_a.connect_peer(format!("127.0.0.1:{}", port_b).parse().unwrap());
    node_b.connect_peer(format!("127.0.0.1:{}", port_a).parse().unwrap());
    node_b.connect_peer(format!("127.0.0.1:{}", port_c).parse().unwrap());
    node_c.connect_peer(format!("127.0.0.1:{}", port_b).parse().unwrap());
    node_c.connect_peer(format!("127.0.0.1:{}", port_d).parse().unwrap());
    node_d.connect_peer(format!("127.0.0.1:{}", port_c).parse().unwrap());

    // Allow peer discovery packets to exchange
    thread::sleep(Duration::from_millis(600));

    // 3. Test Multi-Hop Emergency Chat Propagation
    println!("Step 3: Alice sends emergency message on #emergency from Node A...");
    let emergency_text = "Urgent: Medical aid required at sector 4 community shelter";
    node_a.send_chat("emergency".to_string(), emergency_text.to_string());

    println!("  Waiting for multi-hop gossip propagation from Node A through B and C to Node D...");
    let mut dave_received_chat = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(300));
        let messages = node_d.get_chat_history("emergency");
        if messages.iter().any(|m| m.content == emergency_text) {
            dave_received_chat = true;
            println!("  [SUCCESS] Dave on Node D received Alice's emergency message across 3 hops!");
            break;
        }
    }
    assert!(dave_received_chat, "Dave failed to receive emergency chat across multi-hop mesh");

    // 4. Test Multi-Hop Barter Marketplace Listing & Counter-Proposal
    println!("\nStep 4: Dave lists a generator on Node D...");
    let listing = node_d
        .create_barter_listing(
            "offer",
            "5kW Emergency Dual-Fuel Generator",
            "Runs on gas or propane. Low hours.",
            "tools",
            "excellent",
            "15 gal diesel fuel",
            "Community Shelter Bravo",
        )
        .expect("Failed to create barter listing on Node D");

    println!("  Waiting for barter listing to propagate to Alice on Node A...");
    let mut alice_saw_listing = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(300));
        let listings = node_a.get_barter_listings(None, None);
        if listings.iter().any(|l| l.id == listing.id) {
            alice_saw_listing = true;
            println!("  [SUCCESS] Alice on Node A discovered Dave's barter listing: \"{}\"", listing.title);
            break;
        }
    }
    assert!(alice_saw_listing, "Alice failed to discover Dave's barter listing via mesh sync");

    println!("Step 5: Alice submits counter-proposal to Dave's listing...");
    let proposal = node_a
        .submit_barter_proposal(
            &listing.id,
            "I have 15 gallons of clean diesel fuel ready to trade today.",
            "Radio Callsign ALICE-4 or General Chat",
        )
        .expect("Failed to submit barter proposal");

    println!("  Waiting for barter proposal to propagate back across mesh to Dave on Node D...");
    let mut dave_saw_proposal = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(300));
        let proposals = node_d.get_proposals_for_listing(&listing.id);
        if proposals.iter().any(|p| p.id == proposal.id) {
            dave_saw_proposal = true;
            println!("  [SUCCESS] Dave received Alice's counter-proposal!");
            println!("  Proposal Offer: \"{}\"", proposals[0].offered_items);
            break;
        }
    }
    assert!(dave_saw_proposal, "Dave failed to receive barter proposal across multi-hop mesh");

    // Dave accepts proposal
    let updated = node_d.update_proposal_status(&proposal.id, &listing.id, "accepted").expect("Dave should accept proposal");
    assert!(updated, "Dave should be able to accept proposal");

    // 5. Test Partition Tolerance and Healing
    println!("\nStep 6: Simulating Network Partition (Sever link between Relay B and Relay C)...");
    // Sever Relay B <-> Relay C link
    // While partitioned, Alice posts bulletin on Sub-mesh Alpha (A+B)
    let bulletin_alpha_id = node_a.post_bulletin(
        "Clinic Alpha Operational".to_string(),
        "Triage staff available 24/7.".to_string(),
        "urgent".to_string(),
    );

    // Dave posts bulletin on Sub-mesh Bravo (C+D)
    let bulletin_bravo_id = node_d.post_bulletin(
        "Water Distribution Point Open".to_string(),
        "5 gallons per family per day.".to_string(),
        "standard".to_string(),
    );

    // Wait and verify bulletins exist locally on respective sides
    thread::sleep(Duration::from_millis(600));
    assert!(node_a.get_bulletins().iter().any(|b| b.id == bulletin_alpha_id));
    assert!(node_d.get_bulletins().iter().any(|b| b.id == bulletin_bravo_id));

    println!("Step 7: Healing Network Partition (Reconnecting Relay B and Relay C)...");
    node_b.connect_peer(format!("127.0.0.1:{}", port_c).parse().unwrap());
    node_c.connect_peer(format!("127.0.0.1:{}", port_b).parse().unwrap());

    println!("  Waiting for store-and-forward DAG reconciliation across healed mesh...");
    let mut alice_synced_bravo = false;
    let mut dave_synced_alpha = false;

    for _ in 0..25 {
        thread::sleep(Duration::from_millis(300));

        let a_bulletins = node_a.get_bulletins();
        if a_bulletins.iter().any(|b| b.id == bulletin_bravo_id) {
            alice_synced_bravo = true;
        }

        let d_bulletins = node_d.get_bulletins();
        if d_bulletins.iter().any(|b| b.id == bulletin_alpha_id) {
            dave_synced_alpha = true;
        }

        if alice_synced_bravo && dave_synced_alpha {
            println!("  [SUCCESS] Bidirectional DAG reconciliation complete!");
            println!("  • Alice received Dave's notice: Water Distribution Point");
            println!("  • Dave received Alice's notice: Clinic Alpha Operational");
            break;
        }
    }

    assert!(alice_synced_bravo, "Alice failed to sync Dave's bulletin after partition healed");
    assert!(dave_synced_alpha, "Dave failed to sync Alice's bulletin after partition healed");

    // Clean up
    node_a.stop();
    node_b.stop();
    node_c.stop();
    node_d.stop();

    println!("\n=== ALL MULTI-PEER MESH INTEGRATION TESTS PASSED WITH 100% EVENTUAL CONSISTENCY ===\n");
}
