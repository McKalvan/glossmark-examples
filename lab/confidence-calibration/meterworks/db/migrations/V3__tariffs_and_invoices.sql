CREATE TABLE tariffs (
    code                     text NOT NULL,
    valid_from               date NOT NULL,
    standing_charge_per_day  numeric(8, 4) NOT NULL,
    unit_rate_per_kwh        numeric(8, 4) NOT NULL,
    night_unit_rate_per_kwh  numeric(8, 4),
    PRIMARY KEY (code, valid_from)
);

CREATE TABLE invoices (
    id                uuid PRIMARY KEY,
    customer_id       uuid NOT NULL REFERENCES customers (id),
    service_point_id  uuid NOT NULL REFERENCES service_points (id),
    period_start      date NOT NULL,
    period_end        date NOT NULL,
    consumption_wh    bigint NOT NULL,
    estimated         boolean NOT NULL,
    amount            numeric(10, 2) NOT NULL,
    issued_on         date NOT NULL,
    due_on            date NOT NULL,
    status            text NOT NULL DEFAULT 'ISSUED',
    UNIQUE (service_point_id, period_start)
);

CREATE INDEX invoices_unpaid_idx ON invoices (due_on) WHERE status = 'ISSUED';
