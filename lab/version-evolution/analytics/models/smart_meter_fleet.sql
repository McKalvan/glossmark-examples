-- @gloss represents grid:SmartMeter
-- The communicating meters, with their firmware and last successful read.
CREATE VIEW smart_meter_fleet AS
SELECT m.meter_id,
       m.firmware_version,
       max(r.taken_at) AS last_read_at
FROM meters m
JOIN readings r ON r.meter_id = m.meter_id
WHERE m.comms_type IN ('rf_mesh', 'cellular')
GROUP BY m.meter_id, m.firmware_version;
