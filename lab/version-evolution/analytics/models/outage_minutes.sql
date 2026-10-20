-- @gloss represents grid:Outage
-- Customer minutes lost per feeder per day, the input to the regulator's SAIDI return.
CREATE VIEW outage_minutes AS
SELECT feeder_id,
       date_trunc('day', started_at) AS day,
       sum(customers_affected * extract(epoch FROM (coalesce(restored_at, now()) - started_at)) / 60) AS customer_minutes
FROM outages
GROUP BY feeder_id, date_trunc('day', started_at);
