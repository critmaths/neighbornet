use neighbornet_core::NeighborNode;
use tempfile::tempdir;

#[test]
fn test_48_word_bip39_identity_roundtrip() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let initial_hash = node.get_status().dest_hash;
    assert_eq!(initial_hash.len(), 32); // 16-byte hex address hash

    let mnemonic = node.export_identity_mnemonic().unwrap();
    let words: Vec<&str> = mnemonic.split_whitespace().collect();
    assert_eq!(words.len(), 48); // 48 BIP-39 words for 64-byte Reticulum private key

    let restored_hash = node.restore_identity(&mnemonic).unwrap();
    assert_eq!(restored_hash, initial_hash);
}

#[test]
fn test_restore_from_hex_string_direct() {
    let dir = tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 0, false).unwrap();

    let raw_key_hex = std::fs::read_to_string(dir.path().join("identity.hex")).unwrap();
    let restored_hash = node.restore_identity(&raw_key_hex).unwrap();
    assert_eq!(restored_hash, node.get_status().dest_hash);
}
