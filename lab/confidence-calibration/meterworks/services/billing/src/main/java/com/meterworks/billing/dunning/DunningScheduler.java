package com.meterworks.billing.dunning;

import java.time.Clock;
import java.time.LocalDate;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.meterworks.billing.invoice.Invoice;
import com.meterworks.billing.invoice.InvoiceRepository;

/**
 * Every morning, marks unpaid invoices past their due date overdue and asks
 * the notifications team to send the first reminder letter.
 */
@Component
public class DunningScheduler {
    private static final Logger log = LoggerFactory.getLogger(DunningScheduler.class);

    private final InvoiceRepository invoices;
    private final KafkaTemplate<String, String> kafka;
    private final Clock clock;

    public DunningScheduler(InvoiceRepository invoices, KafkaTemplate<String, String> kafka, Clock clock) {
        this.invoices = invoices;
        this.kafka = kafka;
        this.clock = clock;
    }

    @Scheduled(cron = "0 30 6 * * *", zone = "Europe/London")
    public void chaseOverdueInvoices() {
        LocalDate today = LocalDate.now(clock);
        var overdue = invoices.findUnpaidPastDue(today);
        for (Invoice invoice : overdue) {
            invoices.save(new Invoice(invoice.id(), invoice.customerId(), invoice.servicePointId(),
                    invoice.periodStart(), invoice.periodEnd(), invoice.consumptionWh(), invoice.estimated(),
                    invoice.amount(), invoice.issuedOn(), invoice.dueOn(), Invoice.Status.OVERDUE));
            kafka.send("billing.dunning.v1", invoice.customerId().toString(), invoice.id().toString());
        }
        log.info("dunning: {} invoices overdue on {}", overdue.size(), today);
    }
}
