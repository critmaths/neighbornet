use std::fs;
use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

#[test]
fn test_decentralized_file_sharing_and_chunk_reassembly() {
    println!("\n=== RUNNING DECENTRALIZED FILE CHUNKING & REPLICATION TEST ===");

    let dir_a = tempfile::tempdir().unwrap();
    let dir_b = tempfile::tempdir().unwrap();

    // 1. Launch Node A (Alice) and Node B (Bob / Community Hub)
    println!("Step 1: Starting Node A on port 46110 and Node B on port 46120...");
    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), 46110, false).unwrap();
    node_a.set_nickname("Alice Publisher".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), 46120, true).unwrap();
    node_b.set_nickname("Community Hub".to_string());

    node_b.connect_peer("127.0.0.1:46110".parse().unwrap());
    node_a.connect_peer("127.0.0.1:46120".parse().unwrap());

    // 2. Create a test file that spans multiple 8KB chunks (e.g. 26 KB)
    println!("Step 2: Generating sample emergency document (26 KB multi-chunk)...");
    let test_file_path = dir_a.path().join("Emergency_Water_Purification_Guide.txt");
    let mut sample_content = String::new();
    for i in 0..600 {
        sample_content.push_str(&format!("Line {i}: Community water purification and filtration instructions.\n"));
    }
    fs::write(&test_file_path, &sample_content).unwrap();
    let original_bytes = fs::read(&test_file_path).unwrap();

    // 3. Node A publishes the file
    println!("Step 3: Node A publishes the file to the local network...");
    let file_hash = node_a
        .publish_file(&test_file_path, "Official neighborhood water treatment instructions".to_string())
        .expect("Failed to publish file");
    assert!(!file_hash.is_empty());
    println!("  Published File Hash (SHA-256): {}", file_hash);

    // Verify Node A has it complete
    let path_on_a = node_a.get_completed_file_path(&file_hash);
    assert!(path_on_a.is_some());

    // 4. Wait for Node B to receive file announcement
    println!("Step 4: Waiting for Node B to receive file announcement...");
    let mut announced_on_b = false;
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(300));
        let files_on_b = node_b.get_shared_files();
        if let Some(f) = files_on_b.iter().find(|f| f.file_hash == file_hash) {
            announced_on_b = true;
            println!("  [SUCCESS] Node B received manifest: \"{}\" (chunks: {}, complete: {})", 
                f.filename, f.chunk_count, f.is_complete);
            assert_eq!(f.is_complete, false, "File should initially be incomplete on Node B");
            assert!(f.chunk_count >= 2, "Expected multiple chunks for 26KB file");
            break;
        }
    }
    assert!(announced_on_b, "Node B failed to discover published file announcement");

    // 5. Node B requests the file chunks
    println!("Step 5: Node B initiates chunk transfer request...");
    let request_sent = node_b.request_file(&file_hash);
    assert!(request_sent, "Failed to initiate file request from Node B");

    // 6. Wait for chunks to transfer and auto-assemble on Node B
    println!("Step 6: Waiting for pipelined chunk transfer and SHA-256 verification on Node B...");
    let mut completed_on_b = false;
    for _ in 0..20 {
        thread::sleep(Duration::from_millis(300));
        if let Some(path) = node_b.get_completed_file_path(&file_hash) {
            completed_on_b = true;
            println!("  [SUCCESS] Node B reassembled complete file at: {:?}", path);
            let downloaded_bytes = fs::read(&path).unwrap();
            assert_eq!(downloaded_bytes, original_bytes, "Downloaded bytes do not match original!");
            break;
        }
    }
    assert!(completed_on_b, "Node B failed to complete chunk assembly and verification");

    // 7. Verify file status is now complete on Node B
    let files_b = node_b.get_shared_files();
    let meta_b = files_b.iter().find(|f| f.file_hash == file_hash).unwrap();
    assert!(meta_b.is_complete);
    println!("  Verified file metadata on Node B: is_complete = true, size = {} bytes", meta_b.file_size);

    node_a.stop();
    node_b.stop();
    println!("=== FILE SHARING & VERIFICATION TEST PASSED WITH 100% SUCCESS ===\n");
}
