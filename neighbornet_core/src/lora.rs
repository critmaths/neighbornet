use std::io::{Read, Write};
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use parking_lot::RwLock;
use serde::{Deserialize, Serialize};

use crate::kiss::{
    encode_kiss_frame, KissDecoder, CMD_BANDWIDTH, CMD_CR, CMD_DATA, CMD_FREQUENCY, CMD_SF,
    CMD_STAT_RESP, CMD_TXPOWER,
};

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct SerialDeviceInfo {
    pub port_name: String,
    pub port_type: String,
    pub vid: Option<u16>,
    pub pid: Option<u16>,
    pub manufacturer: Option<String>,
    pub product: Option<String>,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct LoraConfig {
    pub port_name: String,
    pub baud_rate: u32,
    pub freq_hz: u32,
    pub bw_hz: u32,
    pub sf: u8,
    pub cr: u8,
    pub tx_power: u8,
}

impl Default for LoraConfig {
    fn default() -> Self {
        Self {
            port_name: String::new(),
            baud_rate: 115200,
            freq_hz: 915_000_000, // 915 MHz (US ISM band)
            bw_hz: 125_000,       // 125 kHz
            sf: 10,               // Spreading factor 10
            cr: 5,                // 4/5 coding rate
            tx_power: 17,         // 17 dBm
        }
    }
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct LoraStatusReport {
    pub is_connected: bool,
    pub port_name: String,
    pub baud_rate: u32,
    pub freq_hz: u32,
    pub bw_hz: u32,
    pub sf: u8,
    pub cr: u8,
    pub tx_packets: u64,
    pub rx_packets: u64,
    pub last_rssi: i32,
    pub last_snr: i32,
    pub last_activity_epoch_sec: u64,
}

pub type PacketCallback = Arc<dyn Fn(Vec<u8>) + Send + Sync + 'static>;

pub struct LoraManager {
    pub config: RwLock<LoraConfig>,
    pub is_connected: AtomicBool,
    pub tx_packets: AtomicU64,
    pub rx_packets: AtomicU64,
    pub last_rssi: AtomicI32,
    pub last_snr: AtomicI32,
    pub last_activity_sec: AtomicU64,
    pub tx_sender: RwLock<Option<Sender<Vec<u8>>>>,
    pub shutdown_flag: Arc<AtomicBool>,
    pub callback: RwLock<Option<PacketCallback>>,
}

fn current_epoch_sec() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

impl Default for LoraManager {
    fn default() -> Self {
        Self::new()
    }
}

impl LoraManager {
    pub fn new() -> Self {
        Self {
            config: RwLock::new(LoraConfig::default()),
            is_connected: AtomicBool::new(false),
            tx_packets: AtomicU64::new(0),
            rx_packets: AtomicU64::new(0),
            last_rssi: AtomicI32::new(-95), // Default nominal baseline
            last_snr: AtomicI32::new(6),
            last_activity_sec: AtomicU64::new(0),
            tx_sender: RwLock::new(None),
            shutdown_flag: Arc::new(AtomicBool::new(false)),
            callback: RwLock::new(None),
        }
    }

    pub fn set_packet_callback(&self, cb: PacketCallback) {
        *self.callback.write() = Some(cb);
    }

    pub fn list_serial_ports() -> Vec<SerialDeviceInfo> {
        let mut devices = Vec::new();
        if let Ok(ports) = serialport::available_ports() {
            for port in ports {
                let (port_type, vid, pid, manufacturer, product) = match port.port_type {
                    serialport::SerialPortType::UsbPort(usb) => (
                        "USB".to_string(),
                        Some(usb.vid),
                        Some(usb.pid),
                        usb.manufacturer,
                        usb.product,
                    ),
                    serialport::SerialPortType::PciPort => {
                        ("PCI".to_string(), None, None, None, None)
                    }
                    serialport::SerialPortType::BluetoothPort => {
                        ("Bluetooth".to_string(), None, None, None, None)
                    }
                    serialport::SerialPortType::Unknown => {
                        ("Standard".to_string(), None, None, None, None)
                    }
                };

                devices.push(SerialDeviceInfo {
                    port_name: port.port_name,
                    port_type,
                    vid,
                    pid,
                    manufacturer,
                    product,
                });
            }
        }
        devices
    }

    pub fn connect(
        &self,
        port_name: &str,
        baud_rate: u32,
        freq_hz: u32,
        bw_hz: u32,
        sf: u8,
        cr: u8,
    ) -> Result<(), String> {
        self.disconnect();

        let baud = if baud_rate == 0 { 115200 } else { baud_rate };
        let port = serialport::new(port_name, baud)
            .timeout(Duration::from_millis(50))
            .open()
            .map_err(|e| format!("Failed to open serial port '{port_name}': {e}"))?;

        let new_config = LoraConfig {
            port_name: port_name.to_string(),
            baud_rate: baud,
            freq_hz: if freq_hz == 0 { 915_000_000 } else { freq_hz },
            bw_hz: if bw_hz == 0 { 125_000 } else { bw_hz },
            sf: if sf == 0 { 10 } else { sf },
            cr: if cr == 0 { 5 } else { cr },
            tx_power: 17,
        };
        *self.config.write() = new_config.clone();

        let (tx, rx): (Sender<Vec<u8>>, Receiver<Vec<u8>>) = channel();
        *self.tx_sender.write() = Some(tx);

        let shutdown = Arc::new(AtomicBool::new(false));
        self.shutdown_flag.store(false, Ordering::SeqCst);
        let thread_shutdown = shutdown.clone();

        let callback_clone = self.callback.read().clone();
        let tx_counter = Arc::new(AtomicU64::new(self.tx_packets.load(Ordering::Relaxed)));
        let rx_counter = Arc::new(AtomicU64::new(self.rx_packets.load(Ordering::Relaxed)));
        let last_rssi_ref = Arc::new(AtomicI32::new(-95));
        let last_snr_ref = Arc::new(AtomicI32::new(6));
        let last_act_ref = Arc::new(AtomicU64::new(current_epoch_sec()));

        let tx_c_thread = tx_counter.clone();
        let rx_c_thread = rx_counter.clone();
        let rssi_thread = last_rssi_ref.clone();
        let snr_thread = last_snr_ref.clone();
        let act_thread = last_act_ref.clone();

        let _thread_handle = thread::Builder::new()
            .name("lora-serial-io".to_string())
            .spawn(move || {
                let mut serial = port;
                let mut decoder = KissDecoder::new();

                // Send radio configuration frames
                let freq_bytes = new_config.freq_hz.to_be_bytes();
                let _ = serial.write_all(&encode_kiss_frame(CMD_FREQUENCY, &freq_bytes));

                let bw_bytes = new_config.bw_hz.to_be_bytes();
                let _ = serial.write_all(&encode_kiss_frame(CMD_BANDWIDTH, &bw_bytes));

                let _ = serial.write_all(&encode_kiss_frame(CMD_SF, &[new_config.sf]));
                let _ = serial.write_all(&encode_kiss_frame(CMD_CR, &[new_config.cr]));
                let _ = serial.write_all(&encode_kiss_frame(CMD_TXPOWER, &[new_config.tx_power]));
                let _ = serial.flush();

                let mut read_buf = [0u8; 512];

                while !thread_shutdown.load(Ordering::Relaxed) {
                    // 1. Process incoming serial bytes
                    match serial.read(&mut read_buf) {
                        Ok(n) if n > 0 => {
                            for &byte in &read_buf[..n] {
                                if let Some((cmd, payload)) = decoder.feed_byte(byte) {
                                    act_thread.store(current_epoch_sec(), Ordering::Relaxed);
                                    match cmd {
                                        CMD_DATA => {
                                            rx_c_thread.fetch_add(1, Ordering::Relaxed);
                                            if let Some(ref cb) = callback_clone {
                                                cb(payload);
                                            }
                                        }
                                        CMD_STAT_RESP if payload.len() >= 2 => {
                                            let rssi = payload[0] as i8 as i32;
                                            let snr = payload[1] as i8 as i32;
                                            rssi_thread.store(rssi, Ordering::Relaxed);
                                            snr_thread.store(snr, Ordering::Relaxed);
                                        }
                                        _ => {}
                                    }
                                }
                            }
                        }
                        Ok(_) => {}
                        Err(ref e) if e.kind() == std::io::ErrorKind::TimedOut => {}
                        Err(_) => {
                            thread::sleep(Duration::from_millis(20));
                        }
                    }

                    // 2. Process outgoing packets from queue
                    while let Ok(outgoing_payload) = rx.try_recv() {
                        let frame = encode_kiss_frame(CMD_DATA, &outgoing_payload);
                        if serial.write_all(&frame).is_ok() {
                            let _ = serial.flush();
                            tx_c_thread.fetch_add(1, Ordering::Relaxed);
                            act_thread.store(current_epoch_sec(), Ordering::Relaxed);
                        }
                    }

                    thread::sleep(Duration::from_millis(5));
                }
            });

        self.is_connected.store(true, Ordering::SeqCst);
        Ok(())
    }

    pub fn disconnect(&self) {
        self.shutdown_flag.store(true, Ordering::SeqCst);
        self.is_connected.store(false, Ordering::SeqCst);
        *self.tx_sender.write() = None;
    }

    pub fn send_packet(&self, payload: &[u8]) -> bool {
        if !self.is_connected.load(Ordering::Relaxed) {
            return false;
        }

        if let Some(ref sender) = *self.tx_sender.read() {
            if sender.send(payload.to_vec()).is_ok() {
                self.tx_packets.fetch_add(1, Ordering::Relaxed);
                self.last_activity_sec.store(current_epoch_sec(), Ordering::Relaxed);
                return true;
            }
        }
        false
    }

    pub fn get_status(&self) -> LoraStatusReport {
        let conf = self.config.read().clone();
        LoraStatusReport {
            is_connected: self.is_connected.load(Ordering::Relaxed),
            port_name: conf.port_name,
            baud_rate: conf.baud_rate,
            freq_hz: conf.freq_hz,
            bw_hz: conf.bw_hz,
            sf: conf.sf,
            cr: conf.cr,
            tx_packets: self.tx_packets.load(Ordering::Relaxed),
            rx_packets: self.rx_packets.load(Ordering::Relaxed),
            last_rssi: self.last_rssi.load(Ordering::Relaxed),
            last_snr: self.last_snr.load(Ordering::Relaxed),
            last_activity_epoch_sec: self.last_activity_sec.load(Ordering::Relaxed),
        }
    }
}
