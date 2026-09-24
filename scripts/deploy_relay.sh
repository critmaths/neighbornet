#!/usr/bin/env bash
# ==============================================================================
# NeighborNet 24/7 Solar / Raspberry Pi Relay Node Installer
# ==============================================================================
# This script sets up a headless community mesh relay daemon on Debian/Ubuntu/Raspberry Pi OS.
# It configures a systemd service that starts on boot and keeps the local mesh alive.
# ==============================================================================

set -e

RELAY_USER="neighbornet"
RELAY_PORT=42424
RELAY_NICKNAME="SolarHub-$(hostname)"
DATA_DIR="/var/lib/neighbornet"
BIN_PATH="/usr/local/bin/neighbornet_node"
SERVICE_PATH="/etc/systemd/system/neighbornet-relay.service"

echo "====================================================="
echo "   NeighborNet Community Mesh Relay Node Installer   "
echo "====================================================="

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./deploy_relay.sh)"
  exit 1
fi

echo "[+] Creating system user '$RELAY_USER'..."
if ! id "$RELAY_USER" &>/dev/null; then
  useradd --system --no-create-home --shell /bin/false "$RELAY_USER"
fi

echo "[+] Setting up data directory '$DATA_DIR'..."
mkdir -p "$DATA_DIR"
chown -R "$RELAY_USER:$RELAY_USER" "$DATA_DIR"
chmod 700 "$DATA_DIR"

echo "[+] Checking for pre-built binary..."
if [ -f "./target/release/neighbornet_node" ]; then
  cp "./target/release/neighbornet_node" "$BIN_PATH"
elif [ -f "./neighbornet_node" ]; then
  cp "./neighbornet_node" "$BIN_PATH"
else
  echo "[*] Compiling neighbornet_node from source..."
  if ! command -v cargo &>/dev/null; then
    echo "[*] Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
  cargo build --release --bin neighbornet_node
  cp "./target/release/neighbornet_node" "$BIN_PATH"
fi

chmod 755 "$BIN_PATH"

echo "[+] Creating systemd service at '$SERVICE_PATH'..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=NeighborNet Mesh Community Transport Relay Daemon
After=network.target
Wants=network.target

[Service]
Type=simple
User=$RELAY_USER
Group=$RELAY_USER
WorkingDirectory=$DATA_DIR
ExecStart=$BIN_PATH --port $RELAY_PORT --nickname $RELAY_NICKNAME --data-dir $DATA_DIR --transport
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable neighbornet-relay.service
systemctl restart neighbornet-relay.service

echo ""
echo "====================================================="
echo "[✔] NeighborNet Community Relay is ACTIVE on UDP $RELAY_PORT"
echo "====================================================="
echo "Status check:  sudo systemctl status neighbornet-relay"
echo "Live logs:     sudo journalctl -u neighbornet-relay -f"
echo "Data storage:  $DATA_DIR"
echo "====================================================="
