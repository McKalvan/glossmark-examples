package com.meterworks.billing.tariff;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * A price plan: a daily standing charge plus a unit rate, valid from a date.
 * Economy 7 tariffs carry a second, cheaper night rate.
 */
public record Tariff(String code, BigDecimal standingChargePerDay, BigDecimal unitRatePerKwh,
        BigDecimal nightUnitRatePerKwh, LocalDate validFrom) {

    public boolean isEconomy7() {
        return nightUnitRatePerKwh != null;
    }
}
