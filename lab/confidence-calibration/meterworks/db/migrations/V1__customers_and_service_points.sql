-- Customers are account holders; a service point is the supply address a meter is installed at.
CREATE TABLE customers (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_ref   text NOT NULL UNIQUE,
    full_name     text NOT NULL,
    email         text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE service_points (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    mpan          char(13) NOT NULL UNIQUE,
    customer_id   uuid NOT NULL REFERENCES customers (id),
    tariff_code   text NOT NULL,
    supply_start  date NOT NULL,
    supply_end    date
);

CREATE INDEX service_points_customer_idx ON service_points (customer_id);
