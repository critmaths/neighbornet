use std::collections::VecDeque;
use std::io::{Read, Write};
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex};
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

/// Bidirectional in-memory mock serial port for testing, loopback verification,
/// and virtual radio simulation without requiring physical hardware.
#[derive(Clone)]
pub struct MockSerialPort {
    rx: Arc<Mutex<VecDeque<u8>>>,
    tx: Arc<Mutex<VecDeque<u8>>>,
}

impl MockSerialPort {
    /// Creates a connected pair of mock serial ports.
    /// Data written to one end is instantly readable on the other end.
    pub fn pair() -> (Self, Self) {
        let q1 = Arc::new(Mutex::new(VecDeque::new()));
        let q2 = Arc::new(Mutex::new(VecDeque::new()));
        (
            Self {
                rx: q1.clone(),
                tx: q2.clone(),
            },
            Self {
                rx: q2,
                tx: q1,
            },
        )
    }

    /// Read all currently buffered bytes from this port's RX queue.
    pub fn read_available(&self) -> Vec<u8> {
        let mut q = self.rx.lock().unwrap();
        q.drain(..).collect()
    }

    /// Write raw bytes directly into this port's TX queue (to be read by peer).
    pub fn write_bytes(&self, bytes: &[u8]) {
        let mut q = self.tx.lock().unwrap();
        q.extend(bytes);
    }

    /// Read and decode complete KISS frames available in this port's RX queue.
    pub fn read_kiss_frames(&self) -> Vec<(u8, Vec<u8>)> {
        let raw = self.read_available();
        let mut decoder = KissDecoder::new();
        let mut frames = Vec::new();
        for b in raw {
            if let Some(frame) = decoder.feed_byte(b) {
                frames.push(frame);
            }
        }
        frames
    }

    /// Encode and write a KISS frame to the peer.
    pub fn write_kiss_frame(&self, command: u8, payload: &[u8]) {
        let frame = encode_kiss_frame(command, payload);
        self.write_bytes(&frame);
    }
}

impl Read for MockSerialPort {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let mut queue = self.rx.lock().unwrap();
        if queue.is_empty() {
            return Err(std::io::Error::new(std::io::ErrorKind::TimedOut, "timed out"));
        }
        let to_read = buf.len().min(queue.len());
        for i in 0..to_read {
            buf[i] = queue.pop_front().unwrap();
        }
        Ok(to_read)
    }
}

impl Write for MockSerialPort {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let mut queue = self.tx.lock().unwrap();
        queue.extend(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

pub struct LoraManager {
    pub config: RwLock<LoraConfig>,
    pub is_connected: Arc<AtomicBool>,
    pub tx_packets: Arc<AtomicU64>,
    pub rx_packets: Arc<AtomicU64>,
    pub last_rssi: Arc<AtomicI32>,
    pub last_snr: Arc<AtomicI32>,
    pub last_activity_sec: Arc<AtomicU64>,
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
            is_connected: Arc::new(AtomicBool::new(false)),
            tx_packets: Arc::new(AtomicU64::new(0)),
            rx_packets: Arc::new(AtomicU64::new(0)),
            last_rssi: Arc::new(AtomicI32::new(-95)), // Default nominal baseline
            last_snr: Arc::new(AtomicI32::new(6)),
            last_activity_sec: Arc::new(AtomicU64::new(0)),
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

    /// Connects using an arbitrary stream implementing `Read + Write + Send + 'static`.
    /// Used for both physical serial ports and mock/loopback simulation.
    pub fn connect_stream<S: Read + Write + Send + 'static>(
        &self,
        stream: S,
        config: LoraConfig,
    ) -> Result<(), String> {
        self.disconnect();

        *self.config.write() = config.clone();

        let (tx, rx): (Sender<Vec<u8>>, Receiver<Vec<u8>>) = channel();
        *self.tx_sender.write() = Some(tx);

        self.shutdown_flag.store(false, Ordering::SeqCst);
        let thread_shutdown = self.shutdown_flag.clone();
        let is_conn_thread = self.is_connected.clone();

        let callback_clone = self.callback.read().clone();
        let tx_counter = self.tx_packets.clone();
        let rx_counter = self.rx_packets.clone();
        let rssi_thread = self.last_rssi.clone();
        let snr_thread = self.last_snr.clone();
        let act_thread = self.last_activity_sec.clone();

        let cfg = config.clone();

        let _thread_handle = thread::Builder::new()
            .name("lora-serial-io".to_string())
            .spawn(move || {
                let mut serial = stream;
                let mut decoder = KissDecoder::new();

                // Send radio configuration frames
                let freq_bytes = cfg.freq_hz.to_be_bytes();
                let _ = serial.write_all(&encode_kiss_frame(CMD_FREQUENCY, &freq_bytes));

                let bw_bytes = cfg.bw_hz.to_be_bytes();
                let _ = serial.write_all(&encode_kiss_frame(CMD_BANDWIDTH, &bw_bytes));

                let _ = serial.write_all(&encode_kiss_frame(CMD_SF, &[cfg.sf]));
                let _ = serial.write_all(&encode_kiss_frame(CMD_CR, &[cfg.cr]));
                let _ = serial.write_all(&encode_kiss_frame(CMD_TXPOWER, &[cfg.tx_power]));
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
                                            rx_counter.fetch_add(1, Ordering::Relaxed);
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
                            thread::sleep(Duration::from_millis(10));
                        }
                    }

                    // 2. Process outgoing packets from queue
                    while let Ok(outgoing_payload) = rx.try_recv() {
                        let frame = encode_kiss_frame(CMD_DATA, &outgoing_payload);
                        if serial.write_all(&frame).is_ok() {
                            let _ = serial.flush();
                            tx_counter.fetch_add(1, Ordering::Relaxed);
                            act_thread.store(current_epoch_sec(), Ordering::Relaxed);
                        }
                    }

                    thread::sleep(Duration::from_millis(5));
                }

                is_conn_thread.store(false, Ordering::SeqCst);
            })
            .map_err(|e| format!("Failed to spawn lora thread: {e}"))?;

        self.is_connected.store(true, Ordering::SeqCst);
        Ok(())
    }

    /// Connects to a physical serial port.
    pub fn connect(
        &self,
        port_name: &str,
        baud_rate: u32,
        freq_hz: u32,
        bw_hz: u32,
        sf: u8,
        cr: u8,
    ) -> Result<(), String> {
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

        self.connect_stream(port, new_config)
    }

    /// Connects to a mock duplex channel for automated loopback testing and simulation.
    /// Returns the peer MockSerialPort, which behaves as the radio hardware.
    pub fn connect_mock_loopback(&self, config: LoraConfig) -> Result<MockSerialPort, String> {
        let (port, peer) = MockSerialPort::pair();
        self.connect_stream(port, config)?;
        Ok(peer)
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

