use std::net::{Ipv4Addr, UdpSocket};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DnsServerStatus {
    pub is_running: bool,
    pub port: u16,
    pub target_ip: String,
    pub queries_answered: u64,
}

pub struct DnsServer {
    running: Arc<AtomicBool>,
    port: u16,
    target_ip: Ipv4Addr,
    queries_answered: Arc<AtomicU64>,
}

impl Default for DnsServer {
    fn default() -> Self {
        Self::new()
    }
}

impl DnsServer {
    pub fn new() -> Self {
        Self {
            running: Arc::new(AtomicBool::new(false)),
            port: 53,
            target_ip: Ipv4Addr::new(127, 0, 0, 1),
            queries_answered: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn start(&mut self, port: u16, target_ip: Ipv4Addr) -> Result<DnsServerStatus, String> {
        if self.running.load(Ordering::SeqCst) {
            return Ok(self.status());
        }

        let addr = format!("0.0.0.0:{}", port);
        let socket = UdpSocket::bind(&addr)
            .map_err(|e| format!("Failed to bind DNS server to {}: {}", addr, e))?;
        let _ = socket.set_read_timeout(Some(Duration::from_millis(200)));

        self.port = port;
        self.target_ip = target_ip;
        self.running.store(true, Ordering::SeqCst);

        let running_flag = self.running.clone();
        let counter = self.queries_answered.clone();

        thread::spawn(move || {
            let mut buf = [0u8; 1024];
            while running_flag.load(Ordering::SeqCst) {
                match socket.recv_from(&mut buf) {
                    Ok((amt, src)) => {
                        if let Some(resp) = build_dns_response(&buf[..amt], target_ip) {
                            let _ = socket.send_to(&resp, src);
                            counter.fetch_add(1, Ordering::SeqCst);
                        }
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {
                        // Regular timeout so we can check running_flag
                        continue;
                    }
                    Err(_) => {
                        thread::sleep(Duration::from_millis(20));
                    }
                }
            }
        });

        Ok(self.status())
    }

    pub fn stop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
    }

    pub fn status(&self) -> DnsServerStatus {
        DnsServerStatus {
            is_running: self.running.load(Ordering::SeqCst),
            port: self.port,
            target_ip: self.target_ip.to_string(),
            queries_answered: self.queries_answered.load(Ordering::SeqCst),
        }
    }
}

/// Builds an RFC 1035 compliant DNS response to redirect any domain query to `target_ip`.
///
/// - For Type A (IPv4) queries: Returns an authoritative Answer record with `target_ip`.
/// - For Type AAAA (IPv6) queries: Returns NOERROR with 0 answers (prompts immediate IPv4 fallback).
/// - For other types: Returns NOERROR with 0 answers.
pub fn build_dns_response(query: &[u8], target_ip: Ipv4Addr) -> Option<Vec<u8>> {
    // Header must be at least 12 bytes
    if query.len() < 12 {
        return None;
    }

    let tx_id_0 = query[0];
    let tx_id_1 = query[1];
    let qdcount = u16::from_be_bytes([query[4], query[5]]);
    if qdcount == 0 {
        return None;
    }

    // Parse question section
    let mut offset = 12;
    // Walk domain labels
    while offset < query.len() {
        let len = query[offset] as usize;
        if len == 0 {
            offset += 1; // End of domain name
            break;
        }
        if (len & 0xC0) == 0xC0 {
            // Pointer format
            offset += 2;
            break;
        }
        offset += 1 + len;
    }

    // Need 4 bytes for QTYPE (2) and QCLASS (2)
    if offset + 4 > query.len() {
        return None;
    }

    let qtype = u16::from_be_bytes([query[offset], query[offset + 1]]);
    let question_end = offset + 4;
    let question_bytes = &query[12..question_end];

    let is_a_query = qtype == 1 || qtype == 255; // Type A (1) or ANY (255)

    let mut resp = Vec::with_capacity(question_end + 16);

    // 1. Transaction ID
    resp.push(tx_id_0);
    resp.push(tx_id_1);

    // 2. Flags: Standard query response (0x8180 = QR=1, RD=1, RA=1, No error, AA=1 optional 0x8580)
    // 0x8580: Response | Authoritative | Recursion Desired
    resp.push(0x85);
    resp.push(0x80);

    // 3. QDCOUNT: 1
    resp.push(0x00);
    resp.push(0x01);

    // 4. ANCOUNT: 1 for A/ANY queries, 0 for AAAA/others
    if is_a_query {
        resp.push(0x00);
        resp.push(0x01);
    } else {
        resp.push(0x00);
        resp.push(0x00);
    }

    // 5. NSCOUNT: 0
    resp.push(0x00);
    resp.push(0x00);

    // 6. ARCOUNT: 0
    resp.push(0x00);
    resp.push(0x00);

    // 7. Question section (copy verbatim)
    resp.extend_from_slice(question_bytes);

    // 8. Answer section (if Type A query)
    if is_a_query {
        // Name pointer to offset 12 (0xc00c)
        resp.push(0xc0);
        resp.push(0x0c);

        // TYPE: A (0x0001)
        resp.push(0x00);
        resp.push(0x01);

        // CLASS: IN (0x0001)
        resp.push(0x00);
        resp.push(0x01);

        // TTL: 60 seconds (0x0000003c)
        resp.push(0x00);
        resp.push(0x00);
        resp.push(0x00);
        resp.push(0x3c);

        // RDLENGTH: 4 bytes
        resp.push(0x00);
        resp.push(0x04);

        // RDATA: IPv4 octets
        resp.extend_from_slice(&target_ip.octets());
    }

    Some(resp)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_dns_response_for_a_record() {
        // Query for "connectivitycheck.gstatic.com" Type A
        let mut query = vec![
            0x12, 0x34, // ID
            0x01, 0x00, // Standard query, RD=1
            0x00, 0x01, // QDCOUNT = 1
            0x00, 0x00, // ANCOUNT = 0
            0x00, 0x00, // NSCOUNT = 0
            0x00, 0x00, // ARCOUNT = 0
        ];
        // Label "connectivitycheck"
        query.push(17);
        query.extend_from_slice(b"connectivitycheck");
        // Label "gstatic"
        query.push(7);
        query.extend_from_slice(b"gstatic");
        // Label "com"
        query.push(3);
        query.extend_from_slice(b"com");
        // Zero terminator
        query.push(0);
        // QTYPE = 1 (A)
        query.push(0x00);
        query.push(0x01);
        // QCLASS = 1 (IN)
        query.push(0x00);
        query.push(0x01);

        let target_ip = Ipv4Addr::new(10, 0, 0, 1);
        let resp = build_dns_response(&query, target_ip).expect("Should build response");

        // Verify ID match
        assert_eq!(resp[0], 0x12);
        assert_eq!(resp[1], 0x34);

        // Verify Flags QR=1, AA=1, No error
        assert_eq!(resp[2], 0x85);
        assert_eq!(resp[3], 0x80);

        // Verify QDCOUNT = 1, ANCOUNT = 1
        assert_eq!(resp[4..6], [0x00, 0x01]);
        assert_eq!(resp[6..8], [0x00, 0x01]);

        // Verify trailing 4 bytes are IP 10.0.0.1
        let len = resp.len();
        assert_eq!(&resp[len - 4..], &[10, 0, 0, 1]);
    }

    #[test]
    fn test_build_dns_response_for_aaaa_record() {
        // Query for "captive.apple.com" Type AAAA (28 / 0x001c)
        let mut query = vec![
            0xAB, 0xCD, // ID
            0x01, 0x00, // Standard query
            0x00, 0x01, // QDCOUNT = 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        // "apple"
        query.push(5);
        query.extend_from_slice(b"apple");
        // "com"
        query.push(3);
        query.extend_from_slice(b"com");
        query.push(0);
        // QTYPE = 28 (AAAA)
        query.push(0x00);
        query.push(0x1c);
        // QCLASS = 1 (IN)
        query.push(0x00);
        query.push(0x01);

        let target_ip = Ipv4Addr::new(192, 168, 4, 1);
        let resp = build_dns_response(&query, target_ip).expect("Should build response");

        // ANCOUNT should be 0 (no IPv6 answer, forces IPv4 fallback)
        assert_eq!(resp[6..8], [0x00, 0x00]);
    }

    #[test]
    fn test_dns_server_lifecycle() {
        let mut server = DnsServer::new();
        let target_ip = Ipv4Addr::new(10, 42, 0, 1);
        
        // Bind to high unprivileged port for test
        let status = server.start(54321, target_ip).expect("Server should bind to 54321");
        assert!(status.is_running);
        assert_eq!(status.port, 54321);
        assert_eq!(status.target_ip, "10.42.0.1");

        // Send a query via client socket
        let client = UdpSocket::bind("127.0.0.1:0").expect("Client bind");
        client.set_read_timeout(Some(Duration::from_millis(500))).unwrap();

        let query = vec![
            0x99, 0x88, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x04, b't', b'e', b's', b't', 0x00,
            0x00, 0x01, 0x00, 0x01,
        ];
        client.send_to(&query, "127.0.0.1:54321").expect("Send query");

        let mut recv_buf = [0u8; 512];
        let (len, _) = client.recv_from(&mut recv_buf).expect("Receive response");
        assert!(len > 12);
        assert_eq!(&recv_buf[len - 4..len], &[10, 42, 0, 1]);

        let final_status = server.status();
        assert!(final_status.queries_answered >= 1);

        server.stop();
        assert!(!server.status().is_running);
    }
}
