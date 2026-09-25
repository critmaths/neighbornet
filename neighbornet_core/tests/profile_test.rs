use neighbornet_core::NeighborNode;
use std::fs;
use std::thread;
use std::time::Duration;

#[test]
fn test_default_profile_seeded_and_updated() {
    let test_dir = std::env::temp_dir().join("neighbornet_profile_test_1");
    let _ = fs::remove_dir_all(&test_dir);

    // 1. Create node
    let node = NeighborNode::new(test_dir.clone(), 0, false).expect("Failed to start node");

    // 2. Check initial profile
    let initial_profile = node.get_my_profile();
    assert_eq!(initial_profile.dest_hash, node.inner.dest_hash_hex);
    assert!(initial_profile.nickname.starts_with("Neighbor-"));

    // 3. Update profile
    let mut updated_prof = initial_profile.clone();
    updated_prof.nickname = "Alice Alpha".to_string();
    updated_prof.bio = "Emergency CERT responder & Solar technician".to_string();
    updated_prof.callsign = "KD9XYZ".to_string();
    updated_prof.neighborhood_zone = "Sector-4 / Grid B2".to_string();
    updated_prof.contact_info = "Signal: @alice.44".to_string();
    updated_prof.avatar_base64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==".to_string();
    updated_prof.skills = vec![
        "Medical / First Aid".to_string(),
        "Solar & Off-Grid Power".to_string(),
        "HAM Radio Operator".to_string(),
    ];

    let result = node.update_my_profile(updated_prof.clone()).expect("Failed to update profile");
    assert_eq!(result.nickname, "Alice Alpha");
    assert_eq!(result.callsign, "KD9XYZ");
    assert_eq!(result.skills.len(), 3);
    assert_eq!(*node.inner.nickname.read(), "Alice Alpha");

    // 4. Restart node and verify profile is loaded from SQLite
    drop(node);
    let restarted_node = NeighborNode::new(test_dir.clone(), 0, false).expect("Failed to restart node");
    let loaded_prof = restarted_node.get_my_profile();
    assert_eq!(loaded_prof.nickname, "Alice Alpha");
    assert_eq!(loaded_prof.bio, "Emergency CERT responder & Solar technician");
    assert_eq!(loaded_prof.callsign, "KD9XYZ");
    assert_eq!(loaded_prof.neighborhood_zone, "Sector-4 / Grid B2");
    assert_eq!(loaded_prof.skills.len(), 3);
    assert_eq!(loaded_prof.skills[0], "Medical / First Aid");

    let _ = fs::remove_dir_all(test_dir);
}

#[test]
fn test_mesh_profile_sync_between_nodes() {
    let dir1 = std::env::temp_dir().join("neighbornet_profile_sync_node1");
    let dir2 = std::env::temp_dir().join("neighbornet_profile_sync_node2");
    let _ = fs::remove_dir_all(&dir1);
    let _ = fs::remove_dir_all(&dir2);

    let node1 = NeighborNode::new(dir1.clone(), 43101, false).expect("Failed to start node 1");
    let node2 = NeighborNode::new(dir2.clone(), 43102, false).expect("Failed to start node 2");

    node1.connect_peer("127.0.0.1:43102".parse().unwrap());

    // Node 1 configures a rich profile
    let mut p1 = node1.get_my_profile();
    p1.nickname = "Bob Bravo".to_string();
    p1.callsign = "W1AW".to_string();
    p1.bio = "Logistics coordinator and ham radio operator".to_string();
    p1.neighborhood_zone = "Oak Ridge Station".to_string();
    p1.skills = vec!["HAM Radio Operator".to_string(), "Logistics & Supplies".to_string()];
    node1.update_my_profile(p1).expect("Failed to update node 1 profile");

    // Allow background announcements and sync to replicate across nodes
    let node1_hash = node1.inner.dest_hash_hex.clone();
    let mut synced = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(200));
        if let Some(peer_prof) = node2.get_peer_profile(&node1_hash) {
            if peer_prof.nickname == "Bob Bravo" && peer_prof.callsign == "W1AW" && peer_prof.skills.len() == 2 {
                synced = true;
                break;
            }
        }
    }

    assert!(synced, "Node 2 failed to synchronize Node 1's profile over mesh");

    let all_node2_profs = node2.get_all_profiles();
    assert!(all_node2_profs.len() >= 2, "Node 2 should have both its own profile and Node 1's profile");

    let _ = fs::remove_dir_all(dir1);
    let _ = fs::remove_dir_all(dir2);
}
