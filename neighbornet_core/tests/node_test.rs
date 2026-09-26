use std::io::{Read, Write};
use std::net::{TcpStream, UdpSocket};
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::Duration;
use tempfile::tempdir;

struct ChildGuard(Child);

impl Drop for ChildGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

#[test]
fn test_headless_node_daemon_binary_lifecycle_and_services() {
    let bin_path = env!("CARGO_BIN_EXE_neighbornet_node");
    let temp_data_dir = tempdir().unwrap();

    let mesh_port: u16 = 47310;
    let web_gw_port: u16 = 48380;
    let dns_port: u16 = 49353;

    println!("Spawning headless node daemon from: {}", bin_path);

    let child = Command::new(bin_path)
        .arg("-p")
        .arg(mesh_port.to_string())
        .arg("-n")
        .arg("AutomatedRelayDaemon")
        .arg("-d")
        .arg(temp_data_dir.path().to_str().unwrap())
        .arg("-t")
        .arg("-w")
        .arg(web_gw_port.to_string())
        .arg("-z")
        .arg(dns_port.to_string())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("Failed to spawn neighbornet_node binary");

    let _guard = ChildGuard(child);

    // Wait for daemon to bind sockets with retry loop
    let mut connected = false;
    for attempt in 0..25 {
        thread::sleep(Duration::from_millis(250));
        if let Ok(mut stream) = TcpStream::connect(format!("127.0.0.1:{}", web_gw_port)) {
            connected = true;
            println!("Connected to Web Gateway on attempt {}", attempt + 1);

            // 1. Verify Web Gateway HTTP Status
            println!("Testing Web Gateway HTTP status endpoint on port {}...", web_gw_port);
            stream.set_read_timeout(Some(Duration::from_secs(2))).unwrap();

            let request = format!(
                "GET /api/status HTTP/1.1\r\nHost: 127.0.0.1:{}\r\nConnection: close\r\n\r\n",
                web_gw_port
            );
            stream.write_all(request.as_bytes()).unwrap();

            let mut response_str = String::new();
            stream.read_to_string(&mut response_str).unwrap();

            assert!(response_str.contains("200 OK"), "HTTP response must be 200 OK");
            assert!(response_str.contains("AutomatedRelayDaemon"), "Response must contain configured nickname");
            assert!(response_str.contains("\"is_transport\":true"), "Node must report transport mode");
            break;
        }
    }

    assert!(connected, "Failed to connect to Web Gateway HTTP port after retries");

    // 2. Test Captive Portal Probe Interception
    println!("Testing Captive Portal Probe (/generate_204)...");
    let mut probe_stream = TcpStream::connect(format!("127.0.0.1:{}", web_gw_port))
        .expect("Failed to connect for probe");
    probe_stream.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
    let probe_req = format!(
        "GET /generate_204 HTTP/1.1\r\nHost: connectivitycheck.gstatic.com\r\nConnection: close\r\n\r\n"
    );
    probe_stream.write_all(probe_req.as_bytes()).unwrap();
    let mut probe_resp_str = String::new();
    probe_stream.read_to_string(&mut probe_resp_str).unwrap();
    assert!(probe_resp_str.contains("200 OK"), "Probe must return 200 OK");
    assert!(probe_resp_str.contains("NeighborNet"), "Probe must serve the NeighborNet web portal");

    // 3. Test Embedded Captive DNS Redirection Server
    println!("Testing UDP DNS redirection server on port {}...", dns_port);
    let dns_client = UdpSocket::bind("127.0.0.1:0").expect("Failed to bind UDP client socket");
    dns_client.set_read_timeout(Some(Duration::from_secs(2))).unwrap();

    // Query for "google.com" Type A
    let mut dns_query = vec![
        0x56, 0x78, // ID
        0x01, 0x00, // Standard query
        0x00, 0x01, // QDCOUNT = 1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ];
    dns_query.push(6);
    dns_query.extend_from_slice(b"google");
    dns_query.push(3);
    dns_query.extend_from_slice(b"com");
    dns_query.push(0);
    dns_query.push(0x00);
    dns_query.push(0x01); // Type A
    dns_query.push(0x00);
    dns_query.push(0x01); // Class IN

    dns_client
        .send_to(&dns_query, format!("127.0.0.1:{}", dns_port))
        .expect("Failed to send DNS query");

    let mut dns_buf = [0u8; 512];
    let (received_len, _) = dns_client
        .recv_from(&mut dns_buf)
        .expect("Failed to receive DNS response");

    assert!(received_len > 12, "DNS response must have header + payload");
    assert_eq!(dns_buf[0], 0x56, "Transaction ID must match");
    assert_eq!(dns_buf[1], 0x78, "Transaction ID must match");
    assert_eq!(dns_buf[6..8], [0x00, 0x01], "ANCOUNT must be 1");

    println!("All daemon binary subsystems validated successfully!");
}
