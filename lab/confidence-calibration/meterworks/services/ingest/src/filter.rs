use std::collections::HashMap;

use thiserror::Error;

use crate::model::{MeterReading, MeterSerial, Register};

/// The most a domestic supply can draw in half an hour (100 A at 230 V).
/// A larger jump between consecutive reads is a meter fault or a bad frame.
pub const MAX_HALF_HOUR_WH: u64 = 11_500;

#[derive(Debug, Error, PartialEq)]
pub enum Rejected {
    #[error("register went backwards from {previous} to {current} Wh")]
    Backwards { previous: u64, current: u64 },
    #[error("jump of {0} Wh exceeds the half-hour tolerance")]
    Spike(u64),
}

/// Remembers the last accepted value per register and rejects implausible ones.
#[derive(Default)]
pub struct SpikeFilter {
    last: HashMap<(MeterSerial, Register), u64>,
}

impl SpikeFilter {
    pub fn check(&mut self, reading: &MeterReading) -> Result<(), Rejected> {
        let key = (reading.meter_serial.clone(), reading.register);
        if let Some(&previous) = self.last.get(&key) {
            if reading.cumulative_wh < previous {
                return Err(Rejected::Backwards { previous, current: reading.cumulative_wh });
            }
            let delta = reading.cumulative_wh - previous;
            if delta > MAX_HALF_HOUR_WH {
                return Err(Rejected::Spike(delta));
            }
        }
        self.last.insert(key, reading.cumulative_wh);
        Ok(())
    }
}
