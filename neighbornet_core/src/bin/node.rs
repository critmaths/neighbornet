use std::env;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

fn main() {
    let args: Vec<String> = env::args().collect();
    let port: u16 = args.get(1).and_then(|p| p.parse().ok()).unwrap_or(42424);
    let nickname = args.get(2).cloned().unwrap_or_else(|| format!("HubNode-{}", port));
    let is_transport = args.iter().any(|a| a == "--transport");

    println!("=====================================================");
    println!("     NEIGHBORNET RESILIENT COMMUNITY NODE DAEMON     ");
    println!("=====================================================");
    println!("  Mode: {}", if is_transport { "COMMUNITY TRANSPORT NODE / GATEWAY" } else { "EDGE / LEAF NODE" });
    println!("  Listen Port: UDP {}", port);
    println!("  Nickname: {}", nickname);

    let data_dir = PathBuf::from(format!("./data_node_{}", port));
    let node = NeighborNode::new(data_dir, port, is_transport)
        .expect("Failed to initialize Reticulum node socket");

    node.set_nickname(nickname);
    let status = node.get_status();
    println!("  Reticulum Address Hash: {}", status.dest_hash);
    println!("  Stack Engine: Reticulum Network Stack (Rust Core)");
    println!("-----------------------------------------------------");
    println!("Node is active and announcing to local mesh. Press Ctrl+C to stop.");

    let mut last_peer_count = 0;
    let mut last_bulletin_count = 0;

    loop {
        thread::sleep(Duration::from_secs(2));
        let peers = node.get_peers();
        let bulletins = node.get_bulletins();

        if peers.len() != last_peer_count {
            last_peer_count = peers.len();
            println!("\n[MESH DISCOVERY UPDATE] Connected peers: {}", peers.len());
            for p in &peers {
                println!("  • {} ({}) at {} [{}]", p.nickname, p.dest_hash, p.addr, if p.is_transport { "TRANSPORT" } else { "LEAF" });
            }
        }

        if bulletins.len() != last_bulletin_count {
            last_bulletin_count = bulletins.len();
            println!("\n[STORE-AND-FORWARD UPDATE] Total replicated bulletins: {}", bulletins.len());
            if let Some(latest) = bulletins.first() {
                println!("  Latest Notice [{}]: \"{}\" by {}", latest.urgency.to_uppercase(), latest.title, latest.author_nickname);
            }
        }
    }
}
