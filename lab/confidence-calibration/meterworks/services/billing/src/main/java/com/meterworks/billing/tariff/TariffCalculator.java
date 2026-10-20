package com.meterworks.billing.tariff;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.Map;

import org.springframework.stereotype.Component;

/** Prices a month of consumption under the tariff in force on the first day of the month. */
@Component
public class TariffCalculator {
    private final Map<String, Tariff> tariffsByCode;

    public TariffCalculator(TariffCatalogue catalogue) {
        this.tariffsByCode = catalogue.current();
    }

    public BigDecimal price(String tariffCode, long consumptionWh, YearMonth month) {
        Tariff tariff = tariffsByCode.get(tariffCode);
        if (tariff == null) {
            throw new IllegalArgumentException("unknown tariff " + tariffCode);
        }
        BigDecimal kwh = BigDecimal.valueOf(consumptionWh).divide(BigDecimal.valueOf(1000), 3, RoundingMode.HALF_UP);
        BigDecimal standing = tariff.standingChargePerDay().multiply(BigDecimal.valueOf(month.lengthOfMonth()));
        return standing.add(kwh.multiply(tariff.unitRatePerKwh())).setScale(2, RoundingMode.HALF_UP);
    }
}
