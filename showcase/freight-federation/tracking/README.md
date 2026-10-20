# tracking

Kestrel Freight's tracking service. It follows a shipment from pickup to proof of delivery.

- Ingests **GPS pings** from driver devices (`POST /pings`) and **scan events** from depot and handheld scanners (`POST /scans`).
- Starts tracking a shipment on `ShipmentPickedUp` (`shipment.picked-up.v1`).
- Stores planned stops and ETA windows from `RoutePlanned` (`dispatch.routes.v1`).
- Detects **geofence arrival**: a ping within 75 m of the delivery address.
- Records **proof of delivery** (signature, photo or geofence), decides whether the delivery was inside the 2-hour **delivery window**, and publishes `ShipmentDelivered` to `shipment.delivered.v1`.
- Serves the customer tracking API: `GET /tracking/:tracking_number`.

## Topics

| Topic | Direction | Event |
| --- | --- | --- |
| `shipment.picked-up.v1` | consumes | `ShipmentPickedUp` |
| `dispatch.routes.v1` | consumes | `RoutePlanned` |
| `shipment.delivered.v1` | produces | `ShipmentDelivered` |

All payloads use the shared CloudEvents-style envelope (`type`, `id`, `time`, `data`) with camelCase fields. See `src/events/types.rs`.

## HTTP API

| Method | Path | Caller |
| --- | --- | --- |
| `POST` | `/pings` | driver app, batches of up to 500 pings |
| `POST` | `/scans` | depot and handheld scanners |
| `GET` | `/tracking/:tracking_number` | customers |
| `GET` | `/healthz` | load balancer |

Tracking numbers are `KF` + 10 digits + a Luhn check digit, e.g. `KF12345678903`. The tracking endpoint rejects malformed numbers with `422` before touching the database.

## Running locally

```sh
cp .env.example .env
export $(cat .env | xargs)
cargo run --bin tracking
```

Migrations in `migrations/` run on startup.

## Tests

```sh
cargo test
```

The integration tests in `tests/` cover the pure parts of the domain (geofence, delivery window, confirmation decision, scan parsing) and need neither Postgres nor Kafka.

## Further reading

- [docs/geofencing.md](docs/geofencing.md)
- [docs/delivery-confirmation.md](docs/delivery-confirmation.md)
