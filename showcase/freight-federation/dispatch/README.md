# dispatch

Kestrel Freight's dispatch planner. It turns booked shipments into pickup routes for the depot's drivers and reports collections back to the rest of the platform.

- Consumes `ShipmentBooked` from `shipment.booked.v1` and queues a pickup request.
- Plans each driver's pickup route for a day: matches shipments to drivers by zone, vehicle capacity and shift, then optimises the stop order.
- Inserts same-day ExpressPickup requests (booked before 11:00 local) into a live route.
- Confirms pickups from the driver app and publishes `ShipmentPickedUp` on `shipment.picked-up.v1`.
- Publishes `RoutePlanned` on `dispatch.routes.v1` for the tracking service whenever a route is planned or changed.

## Events

| Topic | Event | Direction |
| --- | --- | --- |
| `shipment.booked.v1` | `ShipmentBooked` | consumed (from shipment-core) |
| `shipment.picked-up.v1` | `ShipmentPickedUp` | produced (for tracking, shipment-core) |
| `dispatch.routes.v1` | `RoutePlanned` | produced (for tracking) |

Envelopes are CloudEvents-style JSON (`type`, `id`, `time`, `data`). Payload types live in `src/events/types.ts`; the consumer's view of `ShipmentBooked` is the zod schema in `src/consumer/schemas.ts`, pinned by the contract test in `test/contract/`.

## HTTP API

| Method | Path | Caller | Purpose |
| --- | --- | --- | --- |
| `POST` | `/pickups/:id/confirm` | driver app | Confirm a pickup after scanning the label |
| `GET` | `/pickups?date=YYYY-MM-DD` | ops console | List pickup requests for a day |
| `POST` | `/express-pickups` | shipment-core, customer service | Request same-day collection |
| `GET` | `/routes/:driverId?date=YYYY-MM-DD` | driver app | A driver's route for the day |
| `POST` | `/routes/plan?date=YYYY-MM-DD` | nightly scheduler | Build the day's plan |

## Running locally

```sh
cp .env.example .env
npm install
npx prisma migrate deploy
npm run dev
```

Requires Node 20, Postgres 15+ and a Kafka broker. `npm test` runs the unit tests; `npm run test:contract` runs only the consumer contract tests.

## Layout

```
src/
  server.ts                 Fastify bootstrap, starts the Kafka consumer
  config.ts                 zod-validated environment
  consumer/                 shipment.booked.v1 consumer and payload schema
  planning/                 pickup planner, driver matcher, route optimiser, express pickups
  confirm/                  pickup confirmation
  events/                   producer wrapper and event payload types
  http/                     REST endpoints
prisma/                     schema and migrations
docs/                       planning.md, express-pickup.md
```

See `docs/planning.md` for how a day's plan is built and `docs/express-pickup.md` for same-day pickups.
