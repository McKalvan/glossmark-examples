//! meter-ingest: accepts DLMS frames from the head-end system over TCP,
//! decodes and validates them, and publishes one `ReadingReceived` per register.

mod decoder;
mod filter;
mod model;
mod publisher;

use std::env;

use tokio::io::AsyncReadExt;
use tokio::net::TcpListener;
use tracing::{error, info, warn};

use crate::decoder::decode_frame;
use crate::filter::SpikeFilter;
use crate::publisher::ReadingPublisher;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt().with_env_filter("info").init();

    let listen = env::var("INGEST_LISTEN").unwrap_or_else(|_| "0.0.0.0:4059".to_string());
    let brokers = env::var("KAFKA_BROKERS")?;
    let publisher = ReadingPublisher::connect(&brokers, "meter.readings.v1")?;
    let mut filter = SpikeFilter::default();

    let listener = TcpListener::bind(&listen).await?;
    info!(%listen, "meter-ingest listening");

    loop {
        let (mut socket, peer) = listener.accept().await?;
        let mut buf = vec![0u8; 4096];
        let n = match socket.read(&mut buf).await {
            Ok(n) => n,
            Err(e) => {
                warn!(%peer, error = %e, "read failed");
                continue;
            }
        };
        match decode_frame(&buf[..n]) {
            Ok(readings) => {
                for reading in readings {
                    match filter.check(&reading) {
                        Ok(()) => publisher.publish(&reading).await?,
                        Err(rejected) => warn!(meter = %reading.meter_serial, %rejected, "reading quarantined"),
                    }
                }
            }
            Err(e) => error!(%peer, error = %e, "undecodable frame"),
        }
    }
}
