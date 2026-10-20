use meter_ingest::decoder::{decode_frame, DecodeError};
use meter_ingest::filter::{Rejected, SpikeFilter, MAX_HALF_HOUR_WH};

fn frame(serial: &str, records: &[(u8, u32, u64)]) -> Vec<u8> {
    let mut f = vec![0x7E, serial.len() as u8];
    f.extend_from_slice(serial.as_bytes());
    for (reg, ts, wh) in records {
        f.push(*reg);
        f.extend_from_slice(&ts.to_be_bytes());
        f.extend_from_slice(&wh.to_be_bytes());
    }
    f
}

#[test]
fn decodes_economy7_frame_into_two_readings() {
    let readings = decode_frame(&frame("E7S12345", &[(0x02, 1_700_000_000, 52_000), (0x03, 1_700_000_000, 18_000)])).unwrap();
    assert_eq!(readings.len(), 2);
    assert_eq!(readings[1].cumulative_wh, 18_000);
}

#[test]
fn rejects_frame_without_start_byte() {
    assert!(matches!(decode_frame(&[0x00, 0x01]), Err(DecodeError::BadStart)));
}

#[test]
fn spike_filter_quarantines_implausible_jump() {
    let mut filter = SpikeFilter::default();
    let first = decode_frame(&frame("S1", &[(0x01, 0, 1_000)])).unwrap().remove(0);
    let spike = decode_frame(&frame("S1", &[(0x01, 1_800, 1_000 + MAX_HALF_HOUR_WH + 1)])).unwrap().remove(0);
    assert_eq!(filter.check(&first), Ok(()));
    assert_eq!(filter.check(&spike), Err(Rejected::Spike(MAX_HALF_HOUR_WH + 1)));
}
