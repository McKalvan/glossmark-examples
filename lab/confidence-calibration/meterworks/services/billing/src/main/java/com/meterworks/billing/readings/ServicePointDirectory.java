package com.meterworks.billing.readings;

import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class ServicePointDirectory {
    public record ActiveServicePoint(UUID id, UUID customerId, String tariffCode) {}

    private final JdbcClient jdbc;

    public ServicePointDirectory(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public List<ActiveServicePoint> activeDuring(YearMonth month) {
        return jdbc.sql("""
                SELECT id, customer_id, tariff_code FROM service_points
                WHERE supply_start <= :end AND (supply_end IS NULL OR supply_end >= :start)""")
                .param("start", month.atDay(1))
                .param("end", month.atEndOfMonth())
                .query(ActiveServicePoint.class)
                .list();
    }
}
