package com.meterworks.billing.tariff;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.Map;

import org.junit.jupiter.api.Test;

class TariffCalculatorTest {
    private static Tariff standard() {
        return new Tariff("STD-1", new BigDecimal("0.6012"), new BigDecimal("0.2486"), null, LocalDate.of(2026, 1, 1));
    }

    private static TariffCalculator calculatorWith(Tariff tariff) {
        TariffCatalogue catalogue = mock(TariffCatalogue.class);
        when(catalogue.current()).thenReturn(Map.of(tariff.code(), tariff));
        return new TariffCalculator(catalogue);
    }

    @Test
    void addsStandingChargeForEveryDayOfTheMonth() {
        BigDecimal price = calculatorWith(standard()).price("STD-1", 0, YearMonth.of(2026, 2));
        assertThat(price).isEqualByComparingTo("16.83");
    }

    @Test
    void chargesUnitRatePerKwh() {
        BigDecimal price = calculatorWith(standard()).price("STD-1", 100_000, YearMonth.of(2026, 4));
        assertThat(price).isEqualByComparingTo("42.90");
    }

    @Test
    void unknownTariffIsRejected() {
        assertThatThrownBy(() -> calculatorWith(standard()).price("E7-9", 1, YearMonth.of(2026, 4)))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
