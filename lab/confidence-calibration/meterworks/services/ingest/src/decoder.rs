use chrono::{TimeZone, Utc};
use thiserror::Error;

use crate::model::{MeterReading, MeterSerial, Register};

const FRAME_START: u8 = 0x7E;
const RECORD_LEN: usize = 13;

#[derive(Debug, Error)]
pub enum DecodeError {
    #[error("frame does not start with 0x7E")]
    BadStart,
    #[error("frame truncated at byte {0}")]
    Truncated(usize),
    #[error("unknown register code {0:#x}")]
    UnknownRegister(u8),
}

/// Decodes one head-end frame: a serial, then fixed-size register records.
pub fn decode_frame(frame: &[u8]) -> Result<Vec<MeterReading>, DecodeError> {
    if frame.first() != Some(&FRAME_START) {
        return Err(DecodeError::BadStart);
    }
    let serial_len = *frame.get(1).ok_or(DecodeError::Truncated(1))? as usize;
    let serial_end = 2 + serial_len;
    let serial = frame
        .get(2..serial_end)
        .ok_or(DecodeError::Truncated(serial_end))?;
    let meter_serial = MeterSerial(String::from_utf8_lossy(serial).into_owned());

    let mut out = Vec::new();
    for (i, rec) in frame[serial_end..].chunks(RECORD_LEN).enumerate() {
        if rec.len() < RECORD_LEN {
            return Err(DecodeError::Truncated(serial_end + i * RECORD_LEN));
        }
        out.push(MeterReading {
            meter_serial: meter_serial.clone(),
            register: register_for(rec[0])?,
            read_at: Utc.timestamp_opt(i64::from(u32::from_be_bytes([rec[1], rec[2], rec[3], rec[4]])), 0).unwrap(),
            cumulative_wh: u64::from_be_bytes([rec[5], rec[6], rec[7], rec[8], rec[9], rec[10], rec[11], rec[12]]),
        });
    }
    Ok(out)
}

fn register_for(code: u8) -> Result<Register, DecodeError> {
    match code {
        0x01 => Ok(Register::Single),
        0x02 => Ok(Register::Day),
        0x03 => Ok(Register::Night),
        other => Err(DecodeError::UnknownRegister(other)),
    }
}
