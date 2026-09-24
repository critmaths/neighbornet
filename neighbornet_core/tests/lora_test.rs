use neighbornet_core::kiss::{encode_kiss_frame, KissDecoder, CMD_DATA, FEND, FESC, TFEND, TFESC};
use neighbornet_core::lora::LoraManager;

#[test]
fn test_kiss_frame_encoding_and_escaping() {
    let payload = vec![0x01, FEND, 0x02, FESC, 0x03];
    let encoded = encode_kiss_frame(CMD_DATA, &payload);

    assert_eq!(encoded[0], FEND);
    assert_eq!(encoded[1], CMD_DATA);
    assert_eq!(*encoded.last().unwrap(), FEND);

    assert!(encoded.windows(2).any(|w| w == [FESC, TFEND]));
    assert!(encoded.windows(2).any(|w| w == [FESC, TFESC]));
}

#[test]
fn test_kiss_frame_streaming_decoder_roundtrip() {
    let original_payload = b"Hello sovereign off-grid LoRa mesh!".to_vec();
    let encoded = encode_kiss_frame(CMD_DATA, &original_payload);

    let mut decoder = KissDecoder::new();
    let mut decoded_frames = Vec::new();

    for byte in encoded {
        if let Some(frame) = decoder.feed_byte(byte) {
            decoded_frames.push(frame);
        }
    }

    assert_eq!(decoded_frames.len(), 1);
    let (cmd, payload) = &decoded_frames[0];
    assert_eq!(*cmd, CMD_DATA);
    assert_eq!(payload, &original_payload);
}

#[test]
fn test_lora_manager_lifecycle_and_status() {
    let mgr = LoraManager::new();
    let status = mgr.get_status();
    assert!(!status.is_connected);
    assert_eq!(status.freq_hz, 915_000_000);
    assert_eq!(status.sf, 10);
    assert_eq!(status.tx_packets, 0);
    assert_eq!(status.rx_packets, 0);

    let ports = LoraManager::list_serial_ports();
    println!("Detected system serial ports: {:?}", ports);
}
