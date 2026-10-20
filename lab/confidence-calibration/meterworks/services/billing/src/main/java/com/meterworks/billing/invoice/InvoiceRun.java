package com.meterworks.billing.invoice;

import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.meterworks.billing.config.BillingProperties;
import com.meterworks.billing.estimate.ReadingEstimator;
import com.meterworks.billing.readings.ReadingStore;
import com.meterworks.billing.readings.ServicePointDirectory;
import com.meterworks.billing.tariff.TariffCalculator;

/**
 * The monthly invoice run: one invoice per active service point for the month
 * that just closed, from actual reads where we have them and an estimate where
 * we do not.
 */
@Service
public class InvoiceRun {
    private static final Logger log = LoggerFactory.getLogger(InvoiceRun.class);

    private final ServicePointDirectory servicePoints;
    private final ReadingStore readings;
    private final ReadingEstimator estimator;
    private final TariffCalculator tariffs;
    private final InvoiceRepository invoices;
    private final BillingProperties properties;
    private final Clock clock;

    public InvoiceRun(ServicePointDirectory servicePoints, ReadingStore readings, ReadingEstimator estimator,
            TariffCalculator tariffs, InvoiceRepository invoices, BillingProperties properties, Clock clock) {
        this.servicePoints = servicePoints;
        this.readings = readings;
        this.estimator = estimator;
        this.tariffs = tariffs;
        this.invoices = invoices;
        this.properties = properties;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 3 1 * *", zone = "Europe/London")
    public void runForPreviousMonth() {
        YearMonth month = YearMonth.now(clock).minusMonths(1);
        int issued = 0;
        for (var sp : servicePoints.activeDuring(month)) {
            if (invoices.existsByServicePointIdAndPeriodStart(sp.id(), month.atDay(1))) {
                continue;
            }
            invoices.save(bill(sp.id(), sp.customerId(), sp.tariffCode(), month));
            issued++;
        }
        log.info("invoice run for {} issued {} invoices", month, issued);
    }

    Invoice bill(UUID servicePointId, UUID customerId, String tariffCode, YearMonth month) {
        LocalDate start = month.atDay(1);
        LocalDate end = month.atEndOfMonth();
        var actual = readings.consumptionBetween(servicePointId, start, end);
        boolean estimated = actual.isEmpty()
                || actual.get().lastReadOn().isBefore(end.minusDays(properties.estimateAfterDays()));
        long wh = estimated ? estimator.estimate(servicePointId, start, end) : actual.get().wh();
        LocalDate today = LocalDate.now(clock);
        return new Invoice(UUID.randomUUID(), customerId, servicePointId, start, end, wh, estimated,
                tariffs.price(tariffCode, wh, month), today, today.plusDays(properties.paymentTermsDays()),
                Invoice.Status.ISSUED);
    }
}
