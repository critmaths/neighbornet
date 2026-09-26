use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use neighbornet_core::kiss::{
    encode_kiss_frame, KissDecoder, CMD_BANDWIDTH, CMD_CR, CMD_DATA, CMD_FREQUENCY, CMD_SF,
    CMD_STAT_RESP, CMD_TXPOWER, FEND, FESC, TFEND, TFESC,
};
use neighbornet_core::lora::{LoraConfig, LoraManager, MockSerialPort};

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
fn test_kiss_edge_case_byte_stuffing() {
    // Test payloads with multiple back-to-back delimiter and escape bytes
    let edge_payload = vec![
        FEND, FEND, FESC, FESC, TFEND, TFESC, 0x00, 0xFF, FEND, 0x42, FESC,
    ];
    let encoded = encode_kiss_frame(CMD_DATA, &edge_payload);

    let mut decoder = KissDecoder::new();
    let mut decoded = Vec::new();
    for b in encoded {
        if let Some(frame) = decoder.feed_byte(b) {
            decoded.push(frame);
        }
    }

    assert_eq!(decoded.len(), 1);
    assert_eq!(decoded[0].0, CMD_DATA);
    assert_eq!(decoded[0].1, edge_payload);
}

#[test]
fn test_lora_manager_mock_loopback_initialization() {
    let mgr = LoraManager::new();
    let config = LoraConfig {
        port_name: "COM_MOCK".to_string(),
        baud_rate: 115200,
        freq_hz: 915_000_000,
        bw_hz: 125_000,
        sf: 11,
        cr: 6,
        tx_power: 20,
    };

    let peer = mgr
        .connect_mock_loopback(config.clone())
        .expect("mock loopback connect failed");

    // Wait briefly for background thread to execute initial config transmission
    thread::sleep(Duration::from_millis(50));

    let status = mgr.get_status();
    assert!(status.is_connected);
    assert_eq!(status.port_name, "COM_MOCK");
    assert_eq!(status.freq_hz, 915_000_000);
    assert_eq!(status.bw_hz, 125_000);
    assert_eq!(status.sf, 11);
    assert_eq!(status.cr, 6);

    // Verify all radio initialization frames were sent over KISS to the peer
    let init_frames = peer.read_kiss_frames();
    assert!(!init_frames.is_empty(), "expected radio initialization frames");

    let mut saw_freq = false;
    let mut saw_bw = false;
    let mut saw_sf = false;
    let mut saw_cr = false;
    let mut saw_power = false;

    for (cmd, payload) in init_frames {
        match cmd {
            CMD_FREQUENCY => {
                assert_eq!(payload, 915_000_000u32.to_be_bytes());
                saw_freq = true;
            }
            CMD_BANDWIDTH => {
                assert_eq!(payload, 125_000u32.to_be_bytes());
                saw_bw = true;
            }
            CMD_SF => {
                assert_eq!(payload, vec![11]);
                saw_sf = true;
            }
            CMD_CR => {
                assert_eq!(payload, vec![6]);
                saw_cr = true;
            }
            CMD_TXPOWER => {
                assert_eq!(payload, vec![20]);
                saw_power = true;
            }
            _ => {}
        }
    }

    assert!(saw_freq, "CMD_FREQUENCY frame missing");
    assert!(saw_bw, "CMD_BANDWIDTH frame missing");
    assert!(saw_sf, "CMD_SF frame missing");
    assert!(saw_cr, "CMD_CR frame missing");
    assert!(saw_power, "CMD_TXPOWER frame missing");

    mgr.disconnect();
}

#[test]
fn test_lora_manager_loopback_packet_transmission_and_reception() {
    let mgr = LoraManager::new();
    let rx_packets: Arc<Mutex<Vec<Vec<u8>>>> = Arc::new(Mutex::new(Vec::new()));
    let rx_packets_cb = rx_packets.clone();

    mgr.set_packet_callback(Arc::new(move |payload: Vec<u8>| {
        rx_packets_cb.lock().unwrap().push(payload);
    }));

    let peer = mgr
        .connect_mock_loopback(LoraConfig::default())
        .expect("mock loopback connect failed");

    // Drain initial config frames
    thread::sleep(Duration::from_millis(50));
    let _ = peer.read_kiss_frames();

    // 1. Test TX: Manager sends packet to radio
    let outgoing_payload = b"Emergency Sovereign Broadcast #001".to_vec();
    let sent = mgr.send_packet(&outgoing_payload);
    assert!(sent, "send_packet returned false");

    // Give background worker thread time to pull from queue and write to serial
    thread::sleep(Duration::from_millis(60));

    let frames_from_mgr = peer.read_kiss_frames();
    assert_eq!(frames_from_mgr.len(), 1);
    assert_eq!(frames_from_mgr[0].0, CMD_DATA);
    assert_eq!(frames_from_mgr[0].1, outgoing_payload);

    let status = mgr.get_status();
    assert_eq!(status.tx_packets, 1);

    // 2. Test RX: Radio receives packet from the air and sends it to Manager
    let incoming_payload = b"Relay node ACK from ridge".to_vec();
    peer.write_kiss_frame(CMD_DATA, &incoming_payload);

    // Give background worker thread time to read and invoke callback
    thread::sleep(Duration::from_millis(60));

    let received = rx_packets.lock().unwrap().clone();
    assert_eq!(received.len(), 1);
    assert_eq!(received[0], incoming_payload);

    let status = mgr.get_status();
    assert_eq!(status.rx_packets, 1);

    mgr.disconnect();
}

#[test]
fn test_lora_telemetry_reporting() {
    let mgr = LoraManager::new();
    let peer = mgr
        .connect_mock_loopback(LoraConfig::default())
        .expect("mock loopback connect failed");

    thread::sleep(Duration::from_millis(50));
    let _ = peer.read_kiss_frames();

    // Initial nominal status baseline
    let status_init = mgr.get_status();
    assert_eq!(status_init.last_rssi, -95);
    assert_eq!(status_init.last_snr, 6);

    // Radio sends telemetry update: RSSI = -74 dBm, SNR = +9 dB
    let rssi_byte = (-74i8) as u8;
    let snr_byte = 9i8 as u8;
    peer.write_kiss_frame(CMD_STAT_RESP, &[rssi_byte, snr_byte]);

    thread::sleep(Duration::from_millis(60));

    let status_updated = mgr.get_status();
    assert_eq!(status_updated.last_rssi, -74);
    assert_eq!(status_updated.last_snr, 9);

    // Radio sends fringe signal telemetry: RSSI = -118 dBm, SNR = -5 dB
    let weak_rssi = (-118i8) as u8;
    let weak_snr = (-5i8) as u8;
    peer.write_kiss_frame(CMD_STAT_RESP, &[weak_rssi, weak_snr]);

    thread::sleep(Duration::from_millis(60));

    let status_fringe = mgr.get_status();
    assert_eq!(status_fringe.last_rssi, -118);
    assert_eq!(status_fringe.last_snr, -5);

    mgr.disconnect();
}

#[test]
fn test_lora_manager_clean_disconnect_and_reconnect() {
    let mgr = LoraManager::new();
    let _peer1 = mgr
        .connect_mock_loopback(LoraConfig::default())
        .expect("initial loopback connect failed");

    thread::sleep(Duration::from_millis(50));
    assert!(mgr.get_status().is_connected);

    // Disconnect
    mgr.disconnect();
    assert!(!mgr.get_status().is_connected);

    // Verify send_packet fails when disconnected
    let sent_while_disconnected = mgr.send_packet(b"dropped message");
    assert!(!sent_while_disconnected);

    // Reconnect with new configuration
    let mut config2 = LoraConfig::default();
    config2.freq_hz = 920_000_000;
    config2.sf = 12;

    let peer2 = mgr
        .connect_mock_loopback(config2)
        .expect("reconnect loopback failed");

    thread::sleep(Duration::from_millis(50));
    let status_reconnected = mgr.get_status();
    assert!(status_reconnected.is_connected);
    assert_eq!(status_reconnected.freq_hz, 920_000_000);
    assert_eq!(status_reconnected.sf, 12);

    let frames = peer2.read_kiss_frames();
    assert!(frames.iter().any(|(cmd, p)| *cmd == CMD_FREQUENCY && p == &920_000_000u32.to_be_bytes()));

    mgr.disconnect();
}

#[test]
fn test_two_nodes_virtual_lora_mesh_link() {
    // Two independent LoraManager instances connected over a virtual wireless link
    let node_a_mgr = LoraManager::new();
    let node_b_mgr = LoraManager::new();

    let a_received: Arc<Mutex<Vec<Vec<u8>>>> = Arc::new(Mutex::new(Vec::new()));
    let a_received_clone = a_received.clone();
    node_a_mgr.set_packet_callback(Arc::new(move |payload| {
        a_received_clone.lock().unwrap().push(payload);
    }));

    let b_received: Arc<Mutex<Vec<Vec<u8>>>> = Arc::new(Mutex::new(Vec::new()));
    let b_received_clone = b_received.clone();
    node_b_mgr.set_packet_callback(Arc::new(move |payload| {
        b_received_clone.lock().unwrap().push(payload);
    }));

    // Connect node A and node B using a mock serial pair
    let (port_a, port_b) = MockSerialPort::pair();
    node_a_mgr
        .connect_stream(port_a, LoraConfig::default())
        .expect("node a connect failed");
    node_b_mgr
        .connect_stream(port_b, LoraConfig::default())
        .expect("node b connect failed");

    // Wait for initial radio configuration handshakes to settle
    thread::sleep(Duration::from_millis(100));

    // Clear any initial config frames received before data exchange
    a_received.lock().unwrap().clear();
    b_received.lock().unwrap().clear();

    // Node A sends to Node B
    let msg_a_to_b = b"SOS from Mountain Ridge Sector 4".to_vec();
    assert!(node_a_mgr.send_packet(&msg_a_to_b));

    thread::sleep(Duration::from_millis(80));

    let b_packets = b_received.lock().unwrap().clone();
    assert_eq!(b_packets.len(), 1, "Node B did not receive message from Node A");
    assert_eq!(b_packets[0], msg_a_to_b);

    // Node B sends to Node A
    let msg_b_to_a = b"Sector 4 received, medical drone dispatched".to_vec();
    assert!(node_b_mgr.send_packet(&msg_b_to_a));

    thread::sleep(Duration::from_millis(80));

    let a_packets = a_received.lock().unwrap().clone();
    assert_eq!(a_packets.len(), 1, "Node A did not receive response from Node B");
    assert_eq!(a_packets[0], msg_b_to_a);

    // Verify statistics
    assert!(node_a_mgr.get_status().tx_packets >= 1);
    assert!(node_a_mgr.get_status().rx_packets >= 1);
    assert!(node_b_mgr.get_status().tx_packets >= 1);
    assert!(node_b_mgr.get_status().rx_packets >= 1);

    node_a_mgr.disconnect();
    node_b_mgr.disconnect();
}
