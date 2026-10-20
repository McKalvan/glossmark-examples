use std::time::Duration;

use prost::Message;
use rdkafka::config::ClientConfig;
use rdkafka::error::KafkaError;
use rdkafka::producer::{FutureProducer, FutureRecord};

use crate::model::{MeterReading, Register};

pub mod proto {
    include!(concat!(env!("OUT_DIR"), "/meterworks.readings.v1.rs"));
}

/// Publishes accepted readings to Kafka, keyed by meter serial so one meter's
/// readings stay in order on one partition.
pub struct ReadingPublisher {
    producer: FutureProducer,
    topic: String,
}

impl ReadingPublisher {
    pub fn connect(brokers: &str, topic: &str) -> Result<Self, KafkaError> {
        let producer = ClientConfig::new()
            .set("bootstrap.servers", brokers)
            .set("enable.idempotence", "true")
            .create()?;
        Ok(Self { producer, topic: topic.to_string() })
    }

    pub async fn publish(&self, reading: &MeterReading) -> Result<(), KafkaError> {
        let event = proto::ReadingReceived {
            meter_serial: reading.meter_serial.0.clone(),
            register: match reading.register {
                Register::Single => proto::Register::Single as i32,
                Register::Day => proto::Register::Day as i32,
                Register::Night => proto::Register::Night as i32,
            },
            read_at_unix: reading.read_at.timestamp(),
            cumulative_wh: reading.cumulative_wh,
        };
        let payload = event.encode_to_vec();
        self.producer
            .send(
                FutureRecord::to(&self.topic).key(&reading.meter_serial.0).payload(&payload),
                Duration::from_secs(5),
            )
            .await
            .map(|_| ())
            .map_err(|(e, _)| e)
    }
}
