package com.meterworks.billing.invoice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.meterworks.billing.config.BillingProperties;
import com.meterworks.billing.estimate.ReadingEstimator;
import com.meterworks.billing.readings.ReadingStore;
import com.meterworks.billing.readings.ServicePointDirectory;
import com.meterworks.billing.tariff.TariffCalculator;

class InvoiceRunTest {
    private static final YearMonth MARCH = YearMonth.of(2026, 3);
    private final Clock clock = Clock.fixed(Instant.parse("2026-04-01T03:00:00Z"), ZoneId.of("Europe/London"));
    private final UUID servicePoint = UUID.randomUUID();
    private final UUID customer = UUID.randomUUID();

    private ReadingStore readings;
    private ReadingEstimator estimator;
    private InvoiceRun run;

    @BeforeEach
    void setUp() {
        readings = mock(ReadingStore.class);
        estimator = mock(ReadingEstimator.class);
        TariffCalculator tariffs = mock(TariffCalculator.class);
        when(tariffs.price(eq("STD-1"), anyLong(), any())).thenReturn(new BigDecimal("84.12"));
        run = new InvoiceRun(mock(ServicePointDirectory.class), readings, estimator, tariffs,
                new InMemoryInvoiceRepository(), new BillingProperties(14, 35), clock);
    }

    @Test
    void billsActualConsumptionWhenARecentReadExists() {
        when(readings.consumptionBetween(servicePoint, MARCH.atDay(1), MARCH.atEndOfMonth()))
                .thenReturn(Optional.of(new ReadingStore.Consumption(245_000, LocalDate.of(2026, 3, 31))));
        Invoice invoice = run.bill(servicePoint, customer, "STD-1", MARCH);
        assertThat(invoice.estimated()).isFalse();
        assertThat(invoice.consumptionWh()).isEqualTo(245_000);
    }

    @Test
    void fallsBackToAnEstimateWithoutReads() {
        when(readings.consumptionBetween(any(), any(), any())).thenReturn(Optional.empty());
        when(estimator.estimate(servicePoint, MARCH.atDay(1), MARCH.atEndOfMonth())).thenReturn(240_000L);
        Invoice invoice = run.bill(servicePoint, customer, "STD-1", MARCH);
        assertThat(invoice.estimated()).isTrue();
    }

    @Test
    void dueDateFollowsPaymentTerms() {
        when(readings.consumptionBetween(any(), any(), any())).thenReturn(Optional.empty());
        Invoice invoice = run.bill(servicePoint, customer, "STD-1", MARCH);
        assertThat(invoice.dueOn()).isEqualTo(LocalDate.of(2026, 4, 15));
    }
}
