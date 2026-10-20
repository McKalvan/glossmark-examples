use chrono::{DateTime, Utc};
use serde::Serialize;

/// The serial printed on the meter's faceplate; unique per manufacturer.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize)]
pub struct MeterSerial(pub String);

impl std::fmt::Display for MeterSerial {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

/// Which register a value was read from. Economy 7 meters report two.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum Register {
    Day,
    Night,
    Single,
}

/// One cumulative register value at the end of a half-hour interval.
#[derive(Debug, Clone, Serialize)]
pub struct MeterReading {
    pub meter_serial: MeterSerial,
    pub register: Register,
    pub read_at: DateTime<Utc>,
    /// Cumulative watt-hours since the meter was commissioned.
    pub cumulative_wh: u64,
}
