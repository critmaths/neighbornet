use neighbornet_core::NeighborNode;
use tempfile::tempdir;

#[test]
fn test_barter_marketplace_lifecycle_and_persistence() {
    let dir = tempdir().unwrap();
    let data_dir = dir.path().to_path_buf();

    // 1. Initialize node
    let node = NeighborNode::new(data_dir.clone(), 0, false).expect("Node creation failed");

    // 2. Create barter listings
    let listing1 = node
        .create_barter_listing(
            "offer",
            "5 Gallons Gasoline & Stabilizer",
            "Sealed 5gal fuel canister with PRI-G fuel stabilizer.",
            "fuel",
            "new",
            "Seeking 5.56 ammo, solar charge controller, or dry rations",
            "Sector 4 North Checkpoint",
        )
        .expect("Failed to create listing 1");

    assert!(!listing1.id.is_empty());
    assert_eq!(listing1.listing_type, "offer");
    assert_eq!(listing1.category, "fuel");
    assert_eq!(listing1.status, "active");

    let _listing2 = node
        .create_barter_listing(
            "request",
            "Emergency Antibiotics (Amoxicillin)",
            "Urgent request for sealed broad spectrum antibiotics.",
            "medical",
            "new",
            "Offering 100W portable solar folding panel or portable water filtration",
            "West Ridge Field Hospital",
        )
        .expect("Failed to create listing 2");

    let _listing3 = node
        .create_barter_listing(
            "skill",
            "Emergency Solar & Ham Radio Installation",
            "Certified electrician. Can install off-grid solar panels and configure HF/VHF antennas.",
            "skills",
            "na",
            "Offering labor in exchange for mechanical repairs or preserved firewood",
            "Downtown Hub",
        )
        .expect("Failed to create listing 3");

    // 3. Query listings with filters
    let all_listings = node.get_barter_listings(None, None);
    assert_eq!(all_listings.len(), 3);

    let fuel_listings = node.get_barter_listings(Some("fuel"), None);
    assert_eq!(fuel_listings.len(), 1);
    assert_eq!(fuel_listings[0].title, "5 Gallons Gasoline & Stabilizer");

    let skill_listings = node.get_barter_listings(None, Some("skill"));
    assert_eq!(skill_listings.len(), 1);
    assert_eq!(skill_listings[0].title, "Emergency Solar & Ham Radio Installation");

    // 4. Submit barter proposals
    let proposal1 = node
        .submit_barter_proposal(
            &listing1.id,
            "1x Renogy 100W Solar Controller + 2x MRE Packs",
            "Can meet at North Checkpoint midday tomorrow.",
        )
        .expect("Failed to submit proposal");

    assert!(!proposal1.id.is_empty());
    assert_eq!(proposal1.listing_id, listing1.id);
    assert_eq!(proposal1.status, "proposed");

    let proposals = node.get_proposals_for_listing(&listing1.id);
    assert_eq!(proposals.len(), 1);
    assert_eq!(proposals[0].offered_items, "1x Renogy 100W Solar Controller + 2x MRE Packs");

    // 5. Update proposal and listing status
    let prop_updated = node
        .update_proposal_status(&proposal1.id, &listing1.id, "accepted")
        .expect("Failed to update proposal status");
    assert!(prop_updated);

    let list_updated = node
        .update_barter_status(&listing1.id, "pending")
        .expect("Failed to update listing status");
    assert!(list_updated);

    let updated_proposals = node.get_proposals_for_listing(&listing1.id);
    assert_eq!(updated_proposals[0].status, "accepted");

    let updated_listings = node.get_barter_listings(Some("fuel"), None);
    assert_eq!(updated_listings[0].status, "pending");

    // 6. Community trust vouches
    let vouch = node
        .submit_community_vouch(
            &listing1.author_hash,
            5,
            "Honest trader. Prompt exchange and fuel was clean and tested.",
        )
        .expect("Failed to submit vouch");

    assert_eq!(vouch.rating, 5);
    assert_eq!(vouch.target_node_hash, listing1.author_hash);

    let vouches = node.get_vouches_for_node(&listing1.author_hash);
    assert_eq!(vouches.len(), 1);
    assert_eq!(vouches[0].rating, 5);

    // 7. Test SQLite persistence across restart
    node.stop();
    drop(node);

    let node2 = NeighborNode::new(data_dir.clone(), 0, false).expect("Restart node failed");

    let reloaded_listings = node2.get_barter_listings(None, None);
    assert_eq!(reloaded_listings.len(), 3);

    let reloaded_fuel = node2.get_barter_listings(Some("fuel"), None);
    assert_eq!(reloaded_fuel.len(), 1);
    assert_eq!(reloaded_fuel[0].status, "pending");

    let reloaded_proposals = node2.get_proposals_for_listing(&listing1.id);
    assert_eq!(reloaded_proposals.len(), 1);
    assert_eq!(reloaded_proposals[0].status, "accepted");

    let reloaded_vouches = node2.get_vouches_for_node(&listing1.author_hash);
    assert_eq!(reloaded_vouches.len(), 1);
    assert_eq!(reloaded_vouches[0].review_comment, "Honest trader. Prompt exchange and fuel was clean and tested.");

    // 8. Emergency Panic Wipe
    node2.panic_wipe().expect("Panic wipe failed");

    assert_eq!(node2.get_barter_listings(None, None).len(), 0);
    assert_eq!(node2.get_proposals_for_listing(&listing1.id).len(), 0);
    assert_eq!(node2.get_vouches_for_node(&listing1.author_hash).len(), 0);

    node2.stop();
}
