package com.meterworks.billing.readings;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class ReadingStore {
    public record Consumption(long wh, LocalDate lastReadOn) {}

    private final JdbcClient jdbc;

    public ReadingStore(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public void append(String meterSerial, String register, long readAtUnix, long cumulativeWh) {
        jdbc.sql("""
                INSERT INTO meter_readings (meter_serial, register, read_at, cumulative_wh)
                VALUES (:serial, :register, :readAt, :wh) ON CONFLICT DO NOTHING""")
                .param("serial", meterSerial)
                .param("register", register)
                .param("readAt", Instant.ofEpochSecond(readAtUnix))
                .param("wh", cumulativeWh)
                .update();
    }

    public Optional<Consumption> consumptionBetween(UUID servicePointId, LocalDate start, LocalDate end) {
        return jdbc.sql("""
                SELECT max(r.cumulative_wh) - min(r.cumulative_wh) AS wh, max(r.read_at)::date AS last_read_on
                FROM meter_readings r JOIN meters m ON m.serial = r.meter_serial
                WHERE m.service_point_id = :sp AND r.read_at >= :start AND r.read_at < :end
                HAVING count(*) > 1""")
                .param("sp", servicePointId)
                .param("start", start)
                .param("end", end.plusDays(1))
                .query(Consumption.class)
                .optional();
    }
}
