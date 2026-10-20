package com.meterworks.billing.invoice;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** The JSON shape the customer portal reads. Amounts are in pounds, consumption in kWh. */
public record InvoiceDto(UUID id, LocalDate periodStart, LocalDate periodEnd, double consumptionKwh,
        boolean estimated, BigDecimal amount, LocalDate dueOn, String status) {

    static InvoiceDto from(Invoice i) {
        return new InvoiceDto(i.id(), i.periodStart(), i.periodEnd(), i.consumptionWh() / 1000.0, i.estimated(),
                i.amount(), i.dueOn(), i.status().name().toLowerCase());
    }
}
