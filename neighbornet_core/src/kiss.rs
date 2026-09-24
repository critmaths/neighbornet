pub const FEND: u8 = 0xC0; // Frame End delimiter
pub const FESC: u8 = 0xDB; // Frame Escape delimiter
pub const TFEND: u8 = 0xDC; // Transposed Frame End
pub const TFESC: u8 = 0xDD; // Transposed Frame Escape

pub const CMD_DATA: u8 = 0x00; // Data frame (raw payload)
pub const CMD_FREQUENCY: u8 = 0x01; // Set Radio frequency (Hz, 4 bytes big-endian)
pub const CMD_BANDWIDTH: u8 = 0x02; // Set Bandwidth (Hz, 4 bytes big-endian)
pub const CMD_TXPOWER: u8 = 0x03; // Set TX Power (dBm, 1 byte)
pub const CMD_SF: u8 = 0x04; // Set Spreading Factor (7..12, 1 byte)
pub const CMD_CR: u8 = 0x05; // Set Coding Rate (5..8, 1 byte)
pub const CMD_STAT_REQ: u8 = 0x06; // Request Radio Status / Telemetry
pub const CMD_STAT_RESP: u8 = 0x07; // Radio Status Response (RSSI, SNR, etc.)

/// Encodes a KISS frame with the specified command byte and payload.
pub fn encode_kiss_frame(command: u8, payload: &[u8]) -> Vec<u8> {
    let mut frame = Vec::with_capacity(payload.len() + 8);
    frame.push(FEND);
    frame.push(command);

    for &b in payload {
        match b {
            FEND => {
                frame.push(FESC);
                frame.push(TFEND);
            }
            FESC => {
                frame.push(FESC);
                frame.push(TFESC);
            }
            _ => {
                frame.push(b);
            }
        }
    }

    frame.push(FEND);
    frame
}

/// Streaming KISS decoder that parses incoming serial bytes and yields complete frames.
#[derive(Default)]
pub struct KissDecoder {
    buffer: Vec<u8>,
    in_escape: bool,
    in_frame: bool,
}

impl KissDecoder {
    pub fn new() -> Self {
        Self {
            buffer: Vec::with_capacity(2048),
            in_escape: false,
            in_frame: false,
        }
    }

    pub fn reset(&mut self) {
        self.buffer.clear();
        self.in_escape = false;
        self.in_frame = false;
    }

    /// Feeds a single byte into the decoder. Returns `Some((command, payload))` when a complete frame is finished.
    pub fn feed_byte(&mut self, byte: u8) -> Option<(u8, Vec<u8>)> {
        match byte {
            FEND => {
                if self.in_frame && !self.buffer.is_empty() {
                    let cmd = self.buffer[0];
                    let payload = self.buffer[1..].to_vec();
                    self.buffer.clear();
                    self.in_escape = false;
                    self.in_frame = false;
                    Some((cmd, payload))
                } else {
                    self.buffer.clear();
                    self.in_escape = false;
                    self.in_frame = true;
                    None
                }
            }
            FESC => {
                if self.in_frame {
                    self.in_escape = true;
                }
                None
            }
            TFEND => {
                if self.in_frame {
                    if self.in_escape {
                        self.buffer.push(FEND);
                        self.in_escape = false;
                    } else {
                        self.buffer.push(TFEND);
                    }
                }
                None
            }
            TFESC => {
                if self.in_frame {
                    if self.in_escape {
                        self.buffer.push(FESC);
                        self.in_escape = false;
                    } else {
                        self.buffer.push(TFESC);
                    }
                }
                None
            }
            other => {
                if self.in_frame {
                    self.buffer.push(other);
                    self.in_escape = false;
                }
                None
            }
        }
    }
}
