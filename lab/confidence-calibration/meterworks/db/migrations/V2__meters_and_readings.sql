CREATE TABLE meters (
    serial            text PRIMARY KEY,
    service_point_id  uuid NOT NULL REFERENCES service_points (id),
    economy7          boolean NOT NULL DEFAULT false,
    installed_on      date NOT NULL,
    removed_on        date
);

-- Half-hourly cumulative register values, as published on meter.readings.v1.
CREATE TABLE meter_readings (
    meter_serial   text NOT NULL REFERENCES meters (serial),
    register       text NOT NULL CHECK (register IN ('SINGLE', 'DAY', 'NIGHT')),
    read_at        timestamptz NOT NULL,
    cumulative_wh  bigint NOT NULL,
    PRIMARY KEY (meter_serial, register, read_at)
);
