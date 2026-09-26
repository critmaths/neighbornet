use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use serde::{Deserialize, Serialize};

use crate::NeighborNode;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WebGatewayStatus {
    pub is_running: bool,
    pub port: u16,
    pub local_ip: String,
    pub gateway_url: String,
    pub requests_served: u64,
}

pub struct WebGateway {
    running: Arc<AtomicBool>,
    port: u16,
    local_ip: String,
    requests_served: Arc<AtomicU64>,
}

impl Default for WebGateway {
    fn default() -> Self {
        Self::new()
    }
}

impl WebGateway {
    pub fn new() -> Self {
        Self {
            running: Arc::new(AtomicBool::new(false)),
            port: 8080,
            local_ip: get_local_ip(),
            requests_served: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn start(&mut self, port: u16, node: NeighborNode) -> Result<WebGatewayStatus, String> {
        if self.running.load(Ordering::SeqCst) {
            return Ok(self.status());
        }

        let addr = format!("0.0.0.0:{}", port);
        let listener = TcpListener::bind(&addr).map_err(|e| format!("Failed to bind Web Gateway to {}: {}", addr, e))?;
        let _ = listener.set_nonblocking(true);

        self.port = port;
        self.local_ip = get_local_ip();
        self.running.store(true, Ordering::SeqCst);

        let running_flag = self.running.clone();
        let requests_counter = self.requests_served.clone();

        thread::spawn(move || {
            while running_flag.load(Ordering::SeqCst) {
                match listener.accept() {
                    Ok((stream, _peer_addr)) => {
                        requests_counter.fetch_add(1, Ordering::SeqCst);
                        let node_clone = node.clone();
                        thread::spawn(move || {
                            handle_client(stream, &node_clone);
                        });
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(Duration::from_millis(50));
                    }
                    Err(_) => {
                        thread::sleep(Duration::from_millis(100));
                    }
                }
            }
        });

        Ok(self.status())
    }

    pub fn stop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
    }

    pub fn status(&self) -> WebGatewayStatus {
        let is_running = self.running.load(Ordering::SeqCst);
        let gateway_url = if is_running {
            format!("http://{}:{}", self.local_ip, self.port)
        } else {
            String::new()
        };

        WebGatewayStatus {
            is_running,
            port: self.port,
            local_ip: self.local_ip.clone(),
            gateway_url,
            requests_served: self.requests_served.load(Ordering::SeqCst),
        }
    }
}

fn get_local_ip() -> String {
    if let Ok(socket) = std::net::UdpSocket::bind("0.0.0.0:0") {
        if socket.connect("8.8.8.8:80").is_ok() {
            if let Ok(addr) = socket.local_addr() {
                return addr.ip().to_string();
            }
        }
    }
    "127.0.0.1".to_string()
}

fn handle_client(mut stream: TcpStream, node: &NeighborNode) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(3)));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(3)));

    let mut buffer = [0u8; 8192];
    let mut total_read = 0;
    
    // Read request
    while total_read < buffer.len() {
        match stream.read(&mut buffer[total_read..]) {
            Ok(0) => break,
            Ok(n) => {
                total_read += n;
                if buffer[..total_read].windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
            }
            Err(_) => break,
        }
    }

    if total_read == 0 {
        return;
    }

    let request_str = String::from_utf8_lossy(&buffer[..total_read]);
    let mut lines = request_str.lines();
    let request_line = match lines.next() {
        Some(line) => line,
        None => return,
    };

    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("GET");
    let path = parts.next().unwrap_or("/");

    let body = if let Some(idx) = request_str.find("\r\n\r\n") {
        &request_str[idx + 4..]
    } else {
        ""
    };

    // Route request
    let (status_code, content_type, response_body) = match (method, path) {
        // Captive portal probes
        ("GET", "/generate_204")
        | ("GET", "/gen_204")
        | ("GET", "/hotspot-detect.html")
        | ("GET", "/library/test/success.html")
        | ("GET", "/ncsi.txt")
        | ("GET", "/connecttest.txt") => {
            ("200 OK", "text/html; charset=utf-8", PORTAL_HTML.to_string())
        }

        // Web Portal Single Page App
        ("GET", "/") | ("GET", "/index.html") | ("GET", "/portal") => {
            ("200 OK", "text/html; charset=utf-8", PORTAL_HTML.to_string())
        }

        // REST API: Node Status
        ("GET", "/api/status") => {
            let status = node.get_status();
            let json = serde_json::to_string(&status).unwrap_or_else(|_| "{}".to_string());
            ("200 OK", "application/json", json)
        }

        // REST API: Chat Messages
        ("GET", "/api/messages") | ("GET", "/api/messages/general") => {
            let history = node.get_chat_history("general");
            let json = serde_json::to_string(&history).unwrap_or_else(|_| "[]".to_string());
            ("200 OK", "application/json", json)
        }
        ("POST", "/api/messages") => {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(body) {
                let channel = val["channel"].as_str().unwrap_or("general");
                let content = val["content"].as_str().unwrap_or("");
                if !content.is_empty() {
                    node.send_chat(channel.to_string(), content.to_string());
                    ("200 OK", "application/json", "{\"status\":\"ok\"}".to_string())
                } else {
                    ("400 Bad Request", "application/json", "{\"error\":\"Empty message content\"}".to_string())
                }
            } else {
                ("400 Bad Request", "application/json", "{\"error\":\"Invalid JSON\"}".to_string())
            }
        }

        // REST API: Bulletins
        ("GET", "/api/bulletins") => {
            let list = node.get_bulletins();
            let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
            ("200 OK", "application/json", json)
        }
        ("POST", "/api/bulletins") => {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(body) {
                let title = val["title"].as_str().unwrap_or("");
                let content = val["content"].as_str().unwrap_or("");
                let urgency = val["urgency"].as_str().unwrap_or("standard");
                if !title.is_empty() && !content.is_empty() {
                    node.post_bulletin(title.to_string(), content.to_string(), urgency.to_string());
                    ("200 OK", "application/json", "{\"status\":\"ok\"}".to_string())
                } else {
                    ("400 Bad Request", "application/json", "{\"error\":\"Missing title or content\"}".to_string())
                }
            } else {
                ("400 Bad Request", "application/json", "{\"error\":\"Invalid JSON\"}".to_string())
            }
        }

        // REST API: Barter Listings
        ("GET", "/api/barter") => {
            let list = node.get_barter_listings(None, None);
            let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".to_string());
            ("200 OK", "application/json", json)
        }
        ("POST", "/api/barter") => {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(body) {
                let l_type = val["listing_type"].as_str().unwrap_or("offer");
                let title = val["title"].as_str().unwrap_or("");
                let description = val["description"].as_str().unwrap_or("");
                let category = val["category"].as_str().unwrap_or("general");
                let condition = val["item_condition"].as_str().unwrap_or("good");
                let seeking = val["seeking"].as_str().unwrap_or("");
                let loc = val["location_hint"].as_str().unwrap_or("");

                if !title.is_empty() {
                    match node.create_barter_listing(l_type, title, description, category, condition, seeking, loc) {
                        Ok(item) => {
                            let json = serde_json::to_string(&item).unwrap_or_else(|_| "{}".to_string());
                            ("200 OK", "application/json", json)
                        }
                        Err(e) => ("500 Internal Error", "application/json", format!("{{\"error\":\"{}\"}}", e)),
                    }
                } else {
                    ("400 Bad Request", "application/json", "{\"error\":\"Title required\"}".to_string())
                }
            } else {
                ("400 Bad Request", "application/json", "{\"error\":\"Invalid JSON\"}".to_string())
            }
        }

        // REST API: Peers
        ("GET", "/api/peers") => {
            let peers = node.get_peers();
            let json = serde_json::to_string(&peers).unwrap_or_else(|_| "[]".to_string());
            ("200 OK", "application/json", json)
        }

        // REST API: Emergency SOS
        ("POST", "/api/emergency") => {
            node.send_chat("emergency".to_string(), "EMERGENCY SOS BEACON TRIGGERED VIA WEB GATEWAY".to_string());
            node.post_bulletin("EMERGENCY SOS BROADCAST".to_string(), "An emergency distress alert was triggered from the Web Gateway captive portal.".to_string(), "critical".to_string());
            ("200 OK", "application/json", "{\"status\":\"emergency_broadcasted\"}".to_string())
        }

        _ => ("404 Not Found", "text/plain", "Not Found".to_string()),
    };

    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{}",
        status_code,
        content_type,
        response_body.as_bytes().len(),
        response_body
    );

    let _ = stream.write_all(response.as_bytes());
    let _ = stream.flush();
    let _ = stream.shutdown(std::net::Shutdown::Both);
}

pub const PORTAL_HTML: &str = r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NeighborNet // Zero-Install Mesh Portal</title>
<style>
  :root {
    --bg-main: #0B0F19;
    --bg-card: #131B2E;
    --bg-input: #1E293B;
    --primary: #F59E0B;
    --primary-glow: rgba(245, 158, 11, 0.3);
    --text-main: #F8FAFC;
    --text-muted: #94A3B8;
    --border: rgba(245, 158, 11, 0.25);
    --danger: #EF4444;
    --success: #10B981;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace; }
  body { background-color: var(--bg-main); color: var(--text-main); min-height: 100vh; padding: 16px; }
  .header { display: flex; align-items: center; justify-content: space-between; padding-bottom: 16px; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
  .brand { display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 1.25rem; color: var(--primary); letter-spacing: 0.05em; }
  .badge { background: rgba(16, 185, 129, 0.15); color: var(--success); border: 1px solid var(--success); padding: 4px 10px; border-radius: 9999px; font-size: 0.75rem; font-weight: bold; }
  .nav { display: flex; gap: 8px; overflow-x: auto; margin-bottom: 16px; padding-bottom: 4px; }
  .nav-btn { background: var(--bg-card); color: var(--text-muted); border: 1px solid var(--border); padding: 8px 14px; border-radius: 8px; cursor: pointer; font-size: 0.85rem; font-weight: 600; white-space: nowrap; transition: 0.2s; }
  .nav-btn.active { background: var(--primary); color: #000; border-color: var(--primary); font-weight: 700; box-shadow: 0 0 12px var(--primary-glow); }
  .tab-content { display: none; }
  .tab-content.active { display: block; }
  .card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 16px; margin-bottom: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
  .card-title { font-size: 1.05rem; font-weight: bold; color: var(--primary); margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
  .chat-box { height: 320px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 10px; background: var(--bg-input); border-radius: 8px; border: 1px solid var(--border); margin-bottom: 12px; }
  .msg-bubble { background: rgba(255,255,255,0.05); padding: 8px 12px; border-radius: 8px; font-size: 0.9rem; }
  .msg-sender { font-weight: bold; color: var(--primary); font-size: 0.8rem; margin-bottom: 2px; }
  .msg-time { font-size: 0.7rem; color: var(--text-muted); float: right; }
  .input-row { display: flex; gap: 8px; }
  input, textarea, select { width: 100%; background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border); padding: 10px; border-radius: 8px; font-size: 0.9rem; outline: none; margin-bottom: 10px; }
  input:focus, textarea:focus { border-color: var(--primary); box-shadow: 0 0 8px var(--primary-glow); }
  .btn { background: var(--primary); color: #000; border: none; padding: 10px 18px; border-radius: 8px; font-weight: bold; cursor: pointer; transition: 0.2s; white-space: nowrap; }
  .btn:hover { filter: brightness(1.1); box-shadow: 0 0 10px var(--primary-glow); }
  .btn-danger { background: var(--danger); color: #fff; }
  .sos-banner { background: #3B0D0D; border: 2px solid var(--danger); border-radius: 12px; padding: 16px; text-align: center; margin-bottom: 16px; }
  .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
  .stat-val { font-size: 1.4rem; font-weight: 800; color: var(--primary); }
</style>
</head>
<body>

<div class="header">
  <div class="brand">
    <span>⚡ NEIGHBORNET</span>
  </div>
  <div class="badge" id="node-badge">MESH ONLINE</div>
</div>

<div class="nav">
  <button class="nav-btn active" onclick="switchTab('chat')">💬 Tactical Chat</button>
  <button class="nav-btn" onclick="switchTab('bulletins')">📢 Bulletins</button>
  <button class="nav-btn" onclick="switchTab('barter')">📦 Barter Market</button>
  <button class="nav-btn" onclick="switchTab('manual')">📖 Survival Manual</button>
  <button class="nav-btn" onclick="switchTab('sos')">🚨 SOS Distress</button>
  <button class="nav-btn" onclick="switchTab('status')">📡 Node Health</button>
</div>

<!-- CHAT TAB -->
<div id="tab-chat" class="tab-content active">
  <div class="card">
    <div class="card-title">Live Tactical Mesh Chat</div>
    <div class="chat-box" id="chat-messages">
      <div class="msg-bubble"><div class="msg-sender">System</div>Connecting to mesh node...</div>
    </div>
    <div class="input-row">
      <input type="text" id="chat-input" placeholder="Type tactical message..." onkeydown="if(event.key==='Enter') sendChat()">
      <button class="btn" onclick="sendChat()">Send</button>
    </div>
  </div>
</div>

<!-- BULLETINS TAB -->
<div id="tab-bulletins" class="tab-content">
  <div class="card">
    <div class="card-title">Post New Bulletin</div>
    <input type="text" id="bulletin-title" placeholder="Bulletin Title / Advisory...">
    <textarea id="bulletin-content" rows="3" placeholder="Detailed bulletin content, sitrep, or instructions..."></textarea>
    <select id="bulletin-urgency">
      <option value="standard">Standard Priority</option>
      <option value="urgent">Urgent Advisory</option>
      <option value="critical">Critical / Life Safety</option>
    </select>
    <button class="btn" onclick="postBulletin()">Broadcast Bulletin</button>
  </div>
  <div id="bulletin-list" class="grid-2"></div>
</div>

<!-- BARTER MARKET TAB -->
<div id="tab-barter" class="tab-content">
  <div class="card">
    <div class="card-title">Post Trade / Aid Listing</div>
    <select id="barter-type">
      <option value="offer">Offering Item / Resource</option>
      <option value="request">Requesting / ISO Needed</option>
      <option value="skill">Offering Skill / Service</option>
    </select>
    <input type="text" id="barter-title" placeholder="Item / Skill Title (e.g. 5 Gal Gasoline, Water Filters)...">
    <textarea id="barter-desc" rows="2" placeholder="Description of items or mutual aid..."></textarea>
    <input type="text" id="barter-seeking" placeholder="Wanted in exchange (e.g. AA Batteries, Solar Charging)...">
    <input type="text" id="barter-location" placeholder="Location / Stand / Contact hint...">
    <button class="btn" onclick="postBarter()">Post to Marketplace</button>
  </div>
  <div id="barter-list" class="grid-2"></div>
</div>

<!-- SURVIVAL MANUAL TAB -->
<div id="tab-manual" class="tab-content">
  <div class="card">
    <div class="card-title">Offline Field Survival Protocol</div>
    <div style="font-size:0.9rem; line-height:1.6; color:#E2E8F0;">
      <h3 style="color:var(--primary); margin:12px 0 6px;">💧 Water Purification</h3>
      <p>• Boiling: Vigorous rolling boil for 1 full minute (3 mins at altitude > 2,000m).<br>
      • Bleach: 8 drops (1/8 tsp) regular unscented 6% household bleach per gallon of clear water. Wait 30 minutes.</p>

      <h3 style="color:var(--primary); margin:12px 0 6px;">🏥 START Disaster Medical Triage</h3>
      <p>• <b>Red (Immediate)</b>: Respiration > 30/min, Capillary refill > 2s, or cannot follow commands.<br>
      • <b>Yellow (Delayed)</b>: Serious injuries but stable respiration and perfusion.<br>
      • <b>Green (Minor)</b>: Walking wounded. Can self-assist or aid others.<br>
      • <b>Black (Expectant)</b>: No respiration after airway repositioning.</p>

      <h3 style="color:var(--primary); margin:12px 0 6px;">📻 Emergency Radio Calling Frequencies</h3>
      <p>• 2-Meter VHF National Simplex: 146.520 MHz<br>
      • 70-Centimeter UHF Simplex: 446.000 MHz<br>
      • FRS/GMRS Channel 1: 462.5625 MHz | Channel 20 (Emergency): 462.6750 MHz</p>
    </div>
  </div>
</div>

<!-- SOS TAB -->
<div id="tab-sos" class="tab-content">
  <div class="sos-banner">
    <h2 style="color:var(--danger); margin-bottom:8px;">🚨 EMERGENCY DISTRESS BEACON</h2>
    <p style="font-size:0.9rem; margin-bottom:16px; color:#FECACA;">
      Triggering this SOS beacon immediately broadcasts a high-priority distress signal across the local Reticulum mesh and posts a Critical Life Safety Bulletin to all connected neighbors.
    </p>
    <button class="btn btn-danger" style="font-size:1.1rem; padding:14px 28px;" onclick="triggerSos()">TRIGGER SOS BEACON</button>
  </div>
</div>

<!-- STATUS TAB -->
<div id="tab-status" class="tab-content">
  <div class="grid-2">
    <div class="card">
      <div class="card-title">Mesh Node Status</div>
      <div style="margin-bottom:8px;">Node Nickname: <b id="stat-nick" style="color:var(--primary)">--</b></div>
      <div style="margin-bottom:8px;">Address Hash: <span id="stat-hash" style="font-family:monospace; font-size:0.8rem; word-break:break-all;">--</span></div>
      <div style="margin-bottom:8px;">Mesh UDP Port: <span id="stat-port">42424</span></div>
      <div>Operating Role: <span id="stat-role">Transport Node</span></div>
    </div>
    <div class="card">
      <div class="card-title">Mesh Metrics</div>
      <div style="display:flex; justify-content:space-around; text-align:center; padding:12px 0;">
        <div><div class="stat-val" id="stat-peers">0</div><div style="font-size:0.75rem; color:var(--text-muted)">Peers</div></div>
        <div><div class="stat-val" id="stat-bulletins">0</div><div style="font-size:0.75rem; color:var(--text-muted)">Bulletins</div></div>
        <div><div class="stat-val" id="stat-uptime">0s</div><div style="font-size:0.75rem; color:var(--text-muted)">Uptime</div></div>
      </div>
    </div>
  </div>
</div>

<script>
function switchTab(tabId) {
  document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(el => el.classList.remove('active'));
  document.getElementById('tab-' + tabId).classList.add('active');
  event.target.classList.add('active');
}

async function fetchStatus() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();
    document.getElementById('stat-nick').innerText = data.nickname || 'Unknown';
    document.getElementById('stat-hash').innerText = data.dest_hash || '--';
    document.getElementById('stat-port').innerText = data.listen_port || 42424;
    document.getElementById('stat-role').innerText = data.is_transport ? 'Transport Node' : 'Leaf / Edge Node';
    document.getElementById('stat-peers').innerText = data.peer_count || 0;
    document.getElementById('stat-bulletins').innerText = data.bulletin_count || 0;
    document.getElementById('stat-uptime').innerText = (data.uptime_sec || 0) + 's';
  } catch(e) {}
}

async function fetchChat() {
  try {
    const res = await fetch('/api/messages');
    const msgs = await res.json();
    const box = document.getElementById('chat-messages');
    if (msgs.length === 0) {
      box.innerHTML = '<div class="msg-bubble" style="color:#94A3B8">No messages in channel yet. Say hello to the mesh!</div>';
      return;
    }
    box.innerHTML = msgs.map(m => `
      <div class="msg-bubble">
        <div class="msg-sender">${escapeHtml(m.sender_nickname)} <span class="msg-time">${new Date(m.timestamp_sec * 1000).toLocaleTimeString()}</span></div>
        <div>${escapeHtml(m.content)}</div>
      </div>
    `).join('');
    box.scrollTop = box.scrollHeight;
  } catch(e) {}
}

async function sendChat() {
  const input = document.getElementById('chat-input');
  const text = input.value.trim();
  if (!text) return;
  input.value = '';
  try {
    await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ channel: 'general', content: text })
    });
    fetchChat();
  } catch(e) {}
}

async function fetchBulletins() {
  try {
    const res = await fetch('/api/bulletins');
    const list = await res.json();
    const container = document.getElementById('bulletin-list');
    if (list.length === 0) {
      container.innerHTML = '<div class="card">No bulletins posted yet.</div>';
      return;
    }
    container.innerHTML = list.map(b => `
      <div class="card" style="border-left: 4px solid ${b.urgency === 'critical' ? 'var(--danger)' : b.urgency === 'urgent' ? 'var(--primary)' : 'var(--border)'}">
        <div class="card-title">${escapeHtml(b.title)}</div>
        <div style="font-size:0.8rem; color:var(--text-muted); margin-bottom:8px;">By ${escapeHtml(b.author_nickname)} • ${new Date(b.timestamp_sec * 1000).toLocaleString()}</div>
        <div style="font-size:0.9rem; line-height:1.4;">${escapeHtml(b.content)}</div>
      </div>
    `).join('');
  } catch(e) {}
}

async function postBulletin() {
  const title = document.getElementById('bulletin-title').value.trim();
  const content = document.getElementById('bulletin-content').value.trim();
  const urgency = document.getElementById('bulletin-urgency').value;
  if (!title || !content) { alert('Please enter both title and content.'); return; }
  
  await fetch('/api/bulletins', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, content, urgency })
  });
  document.getElementById('bulletin-title').value = '';
  document.getElementById('bulletin-content').value = '';
  fetchBulletins();
}

async function fetchBarter() {
  try {
    const res = await fetch('/api/barter');
    const list = await res.json();
    const container = document.getElementById('barter-list');
    if (list.length === 0) {
      container.innerHTML = '<div class="card">No barter listings yet.</div>';
      return;
    }
    container.innerHTML = list.map(item => `
      <div class="card">
        <div class="card-title">
          <span>${escapeHtml(item.title)}</span>
          <span style="font-size:0.75rem; text-transform:uppercase; background:rgba(245,158,11,0.2); padding:2px 6px; border-radius:4px;">${item.listing_type}</span>
        </div>
        <div style="font-size:0.85rem; color:var(--text-muted); margin-bottom:6px;">By ${escapeHtml(item.author_nickname)}</div>
        <div style="font-size:0.9rem; margin-bottom:8px;">${escapeHtml(item.description)}</div>
        <div style="font-size:0.85rem; color:var(--primary)"><b>Seeking:</b> ${escapeHtml(item.seeking || 'Any mutual aid')}</div>
      </div>
    `).join('');
  } catch(e) {}
}

async function postBarter() {
  const title = document.getElementById('barter-title').value.trim();
  if (!title) { alert('Title is required'); return; }
  
  await fetch('/api/barter', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      listing_type: document.getElementById('barter-type').value,
      title,
      description: document.getElementById('barter-desc').value.trim(),
      seeking: document.getElementById('barter-seeking').value.trim(),
      location_hint: document.getElementById('barter-location').value.trim(),
      category: 'general',
      item_condition: 'good'
    })
  });
  document.getElementById('barter-title').value = '';
  document.getElementById('barter-desc').value = '';
  document.getElementById('barter-seeking').value = '';
  document.getElementById('barter-location').value = '';
  fetchBarter();
}

async function triggerSos() {
  if (confirm('Are you sure you want to broadcast an EMERGENCY SOS beacon across the mesh?')) {
    await fetch('/api/emergency', { method: 'POST' });
    alert('🚨 Emergency SOS alert has been broadcast across the Reticulum mesh!');
  }
}

function escapeHtml(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Polling intervals
fetchStatus();
fetchChat();
fetchBulletins();
fetchBarter();
setInterval(fetchStatus, 5000);
setInterval(fetchChat, 2000);
setInterval(fetchBulletins, 10000);
setInterval(fetchBarter, 10000);
</script>

</body>
</html>
"#;
