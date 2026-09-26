use std::io::{Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;

use neighbornet_core::NeighborNode;

#[test]
fn test_web_gateway_lifecycle_and_api() {
    let test_dir = PathBuf::from("neighbornet_data_test_webgw");
    let _ = std::fs::remove_dir_all(&test_dir);

    let node = NeighborNode::new(test_dir.clone(), 43888, false).expect("Failed to create test node");

    let port = 48080;
    let status = node.start_web_gateway(port).expect("Failed to start web gateway");
    assert!(status.is_running);
    assert_eq!(status.port, port);

    thread::sleep(Duration::from_millis(150));

    // Test 1: Captive Portal Probe (/generate_204)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    stream.write_all(b"GET /generate_204 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));
    assert!(response.contains("NeighborNet // Zero-Install Mesh Portal"));

    // Test 2: Status API (GET /api/status)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    stream.write_all(b"GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));
    assert!(response.contains("dest_hash"));

    // Test 3: Send Chat Message via REST API (POST /api/messages)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    let body = r#"{"channel":"general","content":"Hello from Captive Portal!"}"#;
    let req = format!(
        "POST /api/messages HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: {}\r\nContent-Type: application/json\r\n\r\n{}",
        body.len(),
        body
    );
    stream.write_all(req.as_bytes()).unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));

    // Test 4: Verify Chat History contains message (GET /api/messages)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    stream.write_all(b"GET /api/messages HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));
    assert!(response.contains("Hello from Captive Portal!"));

    // Test 5: Post Bulletin via REST API (POST /api/bulletins)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    let body = r#"{"title":"Water Distribution Point","content":"Safe drinking water at Town Square.","urgency":"urgent"}"#;
    let req = format!(
        "POST /api/bulletins HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: {}\r\nContent-Type: application/json\r\n\r\n{}",
        body.len(),
        body
    );
    stream.write_all(req.as_bytes()).unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));

    // Test 6: Verify Bulletins API (GET /api/bulletins)
    let mut stream = TcpStream::connect(format!("127.0.0.1:{}", port)).expect("Failed to connect to gateway");
    stream.write_all(b"GET /api/bulletins HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.contains("HTTP/1.1 200 OK"));
    assert!(response.contains("Water Distribution Point"));

    // Test 7: Stop Web Gateway
    node.stop_web_gateway();
    let stopped_status = node.get_web_gateway_status();
    assert!(!stopped_status.is_running);

    node.stop();
    let _ = std::fs::remove_dir_all(&test_dir);
}
