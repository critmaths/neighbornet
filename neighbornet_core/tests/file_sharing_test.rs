use neighbornet_core::NeighborNode;
use std::fs;
use tempfile::tempdir;

#[test]
fn test_publish_file_and_chunk_assembly() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    // Create a temporary file
    let src_file = dir.path().join("emergency_protocol.txt");
    let test_data = b"TACTICAL COMM PROTOCOL: Frequency 915.0 MHz, SF7, BW 125kHz, CR 4/5. Maintain perimeter.";
    fs::write(&src_file, test_data).unwrap();

    let hash = node
        .publish_file(&src_file, "Standard tactical protocol".to_string())
        .expect("publish should succeed");

    assert!(!hash.is_empty());

    let files = node.get_shared_files();
    assert_eq!(files.len(), 1);
    assert_eq!(files[0].filename, "emergency_protocol.txt");
    assert_eq!(files[0].file_hash, hash);
    assert!(files[0].is_complete);
    assert_eq!(files[0].category, "documents");
    assert_eq!(files[0].group_tag, "Public Vault");
    assert!(!files[0].is_encrypted);

    // Verify chunk status
    let status = node.get_file_chunk_status(&hash).expect("chunk status exists");
    assert_eq!(status.file_hash, hash);
    assert_eq!(status.total_chunks, 1);
    assert_eq!(status.downloaded_chunks, 1);
    assert_eq!(status.progress_percent, 100.0);
    assert!(status.is_complete);
    assert!(status.file_path.is_some());

    // Verify export
    let export_path = dir.path().join("exported_protocol.txt");
    let ok = node.export_file(&hash, &export_path, None).expect("export should succeed");
    assert!(ok);
    let exported_bytes = fs::read(&export_path).unwrap();
    assert_eq!(exported_bytes, test_data);
}

#[test]
fn test_encrypted_vault_publish_and_decrypt() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let secret_file = dir.path().join("classified_codes.key");
    let classified_content = b"TOP SECRET: RE-SEED SEED PHRASE WITH STEWARD BACKUP KEY ALPHA-OMEGA-99";
    fs::write(&secret_file, classified_content).unwrap();

    let passphrase = "tactical_secure_passphrase_2026";

    let hash = node
        .publish_file_extended(
            &secret_file,
            "Classified cipher key".to_string(),
            "vault".to_string(),
            "Steward Command".to_string(),
            Some(passphrase.to_string()),
        )
        .expect("encrypted publish succeeds");

    let files = node.get_shared_files();
    let meta = files.iter().find(|f| f.file_hash == hash).unwrap();
    assert!(meta.is_encrypted);
    assert_eq!(meta.category, "vault");
    assert_eq!(meta.group_tag, "Steward Command");
    assert!(!meta.encryption_salt.is_empty());

    // Test export with wrong passphrase -> should fail
    let wrong_export_path = dir.path().join("wrong_decrypted.key");
    let fail_res = node.export_file(&hash, &wrong_export_path, Some("wrong_password"));
    assert!(fail_res.is_err());

    // Test export with correct passphrase -> should succeed and match original
    let correct_export_path = dir.path().join("correct_decrypted.key");
    let ok = node
        .export_file(&hash, &correct_export_path, Some(passphrase))
        .expect("decryption export succeeds");
    assert!(ok);
    let decrypted_bytes = fs::read(&correct_export_path).unwrap();
    assert_eq!(decrypted_bytes, classified_content);
}

#[test]
fn test_delete_shared_file_and_cleanup() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let temp_file = dir.path().join("temporary_map.png");
    fs::write(&temp_file, b"FAKE_PNG_BINARY_BYTES_12345").unwrap();

    let hash = node
        .publish_file_extended(
            &temp_file,
            "Temp Map".to_string(),
            "maps".to_string(),
            "Recon Team".to_string(),
            None,
        )
        .unwrap();

    assert_eq!(node.get_shared_files().len(), 1);

    let deleted = node.delete_shared_file(&hash);
    assert!(deleted);
    assert_eq!(node.get_shared_files().len(), 0);
    assert!(node.get_file_chunk_status(&hash).is_none());
}
