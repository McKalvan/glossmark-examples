package com.meterworks.billing.tariff;

import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class TariffCatalogue {
    private final JdbcClient jdbc;

    public TariffCatalogue(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Tariff> current() {
        return jdbc.sql("""
                SELECT DISTINCT ON (code) code, standing_charge_per_day, unit_rate_per_kwh,
                       night_unit_rate_per_kwh, valid_from
                FROM tariffs WHERE valid_from <= current_date ORDER BY code, valid_from DESC""")
                .query(Tariff.class)
                .list()
                .stream()
                .collect(Collectors.toMap(Tariff::code, Function.identity()));
    }
}
