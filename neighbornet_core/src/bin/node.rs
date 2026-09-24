use std::env;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;
use neighbornet_core::NeighborNode;

fn print_usage() {
    println!("NeighborNet Headless Community Mesh Relay Daemon");
    println!("Usage: neighbornet_node [OPTIONS]");
    println!();
    println!("Options:");
    println!("  -p, --port <PORT>        UDP Port to bind (default: 42424)");
    println!("  -n, --nickname <NAME>    Display nickname on mesh (default: HubNode-<port>)");
    println!("  -d, --data-dir <PATH>    Data directory for SQLite db and keys (default: ./data_node_<port>)");
    println!("  -t, --transport          Enable Community Transport Relay & Routing Mode");
    println!("  -h, --help               Print this help message");
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.iter().any(|a| a == "-h" || a == "--help") {
        print_usage();
        return;
    }

    let mut port: u16 = 42424;
    let mut nickname: Option<String> = None;
    let mut data_dir: Option<PathBuf> = None;
    let mut is_transport = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "-p" | "--port" => {
                if i + 1 < args.len() {
                    port = args[i + 1].parse().unwrap_or(42424);
                    i += 1;
                }
            }
            "-n" | "--nickname" => {
                if i + 1 < args.len() {
                    nickname = Some(args[i + 1].clone());
                    i += 1;
                }
            }
            "-d" | "--data-dir" => {
                if i + 1 < args.len() {
                    data_dir = Some(PathBuf::from(&args[i + 1]));
                    i += 1;
                }
            }
            "-t" | "--transport" => {
                is_transport = true;
            }
            other => {
                // Support legacy positional arguments
                if !other.starts_with('-') {
                    if let Ok(p) = other.parse::<u16>() {
                        port = p;
                    } else if nickname.is_none() {
                        nickname = Some(other.to_string());
                    }
                }
            }
        }
        i += 1;
    }

    let resolved_nickname = nickname.unwrap_or_else(|| format!("HubNode-{}", port));
    let resolved_data_dir = data_dir.unwrap_or_else(|| PathBuf::from(format!("./data_node_{}", port)));

    println!("=====================================================");
    println!("     NEIGHBORNET RESILIENT COMMUNITY NODE DAEMON     ");
    println!("=====================================================");
    println!("  Mode: {}", if is_transport { "COMMUNITY TRANSPORT NODE / GATEWAY (RELAY ACTIVE)" } else { "EDGE / LEAF NODE" });
    println!("  Listen Port: UDP {}", port);
    println!("  Nickname: {}", resolved_nickname);
    println!("  Data Directory: {:?}", resolved_data_dir);

    let node = NeighborNode::new(resolved_data_dir, port, is_transport)
        .expect("Failed to initialize Reticulum node socket");

    node.set_nickname(resolved_nickname);
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
                println!("  • {} ({}) at {} [{}]", p.nickname, p.dest_hash, p.addr, if p.is_transport { "TRANSPORT RELAY" } else { "LEAF" });
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
