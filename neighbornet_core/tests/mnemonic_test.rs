use bip39::Mnemonic;
use reticulum_rs::identity::{HashIdentity, PrivateIdentity};

#[test]
fn test_48_word_bip39_identity_roundtrip() {
    // 1. Generate identity
    let original_identity = PrivateIdentity::new_from_rand(rand_core::OsRng);
    let original_hash = hex::encode(original_identity.as_address_hash_slice());
    let priv_bytes = original_identity.to_private_key_bytes();
    assert_eq!(priv_bytes.len(), 64);

    // 2. Export to 48-word mnemonic phrase (2x 24 words)
    let part1 = &priv_bytes[..32];
    let part2 = &priv_bytes[32..];
    let m1 = Mnemonic::from_entropy(part1).expect("Part 1 entropy");
    let m2 = Mnemonic::from_entropy(part2).expect("Part 2 entropy");

    let phrase = format!("{} {}", m1, m2);
    let words: Vec<&str> = phrase.split_whitespace().collect();
    assert_eq!(words.len(), 48);

    // 3. Restore from 48-word mnemonic phrase
    let words1 = words[..24].join(" ");
    let words2 = words[24..].join(" ");
    let restored_m1 = Mnemonic::parse_normalized(&words1).expect("Parse part 1");
    let restored_m2 = Mnemonic::parse_normalized(&words2).expect("Parse part 2");

    let mut restored_bytes = Vec::with_capacity(64);
    restored_bytes.extend_from_slice(&restored_m1.to_entropy());
    restored_bytes.extend_from_slice(&restored_m2.to_entropy());
    assert_eq!(restored_bytes, priv_bytes);

    let restored_identity = PrivateIdentity::new_from_hex_string(&hex::encode(&restored_bytes))
        .expect("Reconstruct PrivateIdentity");
    let restored_hash = hex::encode(restored_identity.as_address_hash_slice());

    assert_eq!(restored_hash, original_hash, "Restored address hash must match original");
}

#[test]
fn test_restore_from_hex_string_direct() {
    let original_identity = PrivateIdentity::new_from_rand(rand_core::OsRng);
    let original_hash = hex::encode(original_identity.as_address_hash_slice());
    let hex_str = hex::encode(original_identity.to_private_key_bytes());

    let restored_identity = PrivateIdentity::new_from_hex_string(&hex_str)
        .expect("Restore from hex");
    let restored_hash = hex::encode(restored_identity.as_address_hash_slice());

    assert_eq!(restored_hash, original_hash);
}
