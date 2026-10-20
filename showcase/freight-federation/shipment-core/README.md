# shipment-core

Kestrel Freight's system of record for shipments. It:

- books shipments (`POST /shipments`) with their parcels, picks a carrier and promises a two-hour delivery window
- renders shipping labels (`GET /shipments/{id}/label`, ZPL II 4x6 in at 203 dpi)
- publishes `ShipmentBooked` on `shipment.booked.v1` through a transactional outbox
- consumes `ShipmentPickedUp` and `ShipmentDelivered` to keep shipment status current
- reports the 7-day on-time delivery rate (`GET /metrics/on-time-rate`, target 95%)

See [docs/](docs/) for the event catalogue, label format and delivery-window rules.

## Running locally

Requires Java 21, Gradle 8.10+, Postgres 16 and Kafka.

```sh
docker run -d --name shipment-pg -e POSTGRES_USER=shipment_core -e POSTGRES_PASSWORD=shipment_core \
  -e POSTGRES_DB=shipment_core -p 5432:5432 postgres:16
gradle :service:bootRun
```

Configuration is via environment variables: `SHIPMENT_DB_URL`, `SHIPMENT_DB_USER`, `SHIPMENT_DB_PASSWORD`,
`KAFKA_BOOTSTRAP_SERVERS`. Flyway applies migrations on start-up.

## Tests

```sh
gradle test
```

The consumer-driven contract test for `ShipmentBooked` lives in the dispatch repository.
