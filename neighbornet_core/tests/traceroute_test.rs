use neighbornet_core::{NeighborNode, TraceHop, TraceroutePacket, WireEnvelope};
use tempfile::tempdir;

#[test]
fn test_initiate_traceroute_and_persistence() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let target_hash = "f0e1d2c3b4a596877896a5b4c3d2e1f0";
    let trace = node.initiate_traceroute(target_hash, 6).unwrap();

    assert_eq!(trace.target_hash, target_hash);
    assert_eq!(trace.ttl, 6);
    assert_eq!(trace.max_ttl, 6);
    assert_eq!(trace.status, "in_transit");
    assert_eq!(trace.hops.len(), 1);
    assert_eq!(trace.hops[0].node_hash, node.inner.dest_hash_hex);
    assert_eq!(trace.hops[0].delta_ms, 0);

    // Retrieve by ID
    let fetched = node.get_traceroute_by_id(&trace.trace_id).expect("Should find trace by ID");
    assert_eq!(fetched.trace_id, trace.trace_id);
    assert_eq!(fetched.target_hash, target_hash);

    // Retrieve all traces
    let all = node.get_traceroutes();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].trace_id, trace.trace_id);
}

#[test]
fn test_simulate_multi_hop_trace() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let target_hash = "11223344556677889900aabbccddeeff";
    let sim_trace = node.simulate_trace(target_hash).unwrap();

    assert_eq!(sim_trace.target_hash, target_hash);
    assert_eq!(sim_trace.status, "reached_destination");
    assert_eq!(sim_trace.hops.len(), 4);
    assert!(sim_trace.total_rtt_ms.unwrap() > 0);

    // Check intermediate hop details
    assert_eq!(sim_trace.hops[0].interface_type, "Local Host");
    assert_eq!(sim_trace.hops[1].interface_type, "LoRa-915MHz");
    assert!(sim_trace.hops[1].rssi_dbm.is_some());
    assert!(sim_trace.hops[1].snr_db.is_some());
    assert_eq!(sim_trace.hops[3].node_hash, target_hash);

    // Verify persistence across reload
    drop(node);
    let reloaded_node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();
    let reloaded_traces = reloaded_node.get_traceroutes();
    assert_eq!(reloaded_traces.len(), 1);
    assert_eq!(reloaded_traces[0].trace_id, sim_trace.trace_id);
    assert_eq!(reloaded_traces[0].hops.len(), 4);
}

#[test]
fn test_traceroute_wire_envelope_roundtrip() {
    let hop = TraceHop {
        node_hash: "abcd1234ef567890".to_string(),
        nickname: "Relay-Alpha".to_string(),
        callsign: "W7-RLY".to_string(),
        interface_type: "LoRa-915MHz".to_string(),
        rssi_dbm: Some(-76),
        snr_db: Some(8.5),
        timestamp_ms: 1727200000000,
        delta_ms: 22,
    };

    let packet = TraceroutePacket {
        trace_id: "trace-test-123".to_string(),
        origin_hash: "origin00001".to_string(),
        origin_nickname: "Alice".to_string(),
        origin_callsign: "K7-ALC".to_string(),
        target_hash: "target00002".to_string(),
        target_nickname: "Bob".to_string(),
        ttl: 4,
        max_ttl: 8,
        hops: vec![hop],
        status: "in_transit".to_string(),
        created_at_ms: 1727200000000,
        completed_at_ms: None,
        total_rtt_ms: None,
    };

    let envelope = WireEnvelope::TraceRequest(packet.clone());
    let json = serde_json::to_string(&envelope).unwrap();
    let deserialized: WireEnvelope = serde_json::from_str(&json).unwrap();

    match deserialized {
        WireEnvelope::TraceRequest(p) => {
            assert_eq!(p.trace_id, "trace-test-123");
            assert_eq!(p.hops.len(), 1);
            assert_eq!(p.hops[0].callsign, "W7-RLY");
        }
        _ => panic!("Expected TraceRequest variant"),
    }
}

#[test]
fn test_panic_wipe_resets_traceroutes() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let _ = node.simulate_trace("target123456").unwrap();
    assert_eq!(node.get_traceroutes().len(), 1);

    node.panic_wipe().unwrap();
    assert_eq!(node.get_traceroutes().len(), 0);
}
