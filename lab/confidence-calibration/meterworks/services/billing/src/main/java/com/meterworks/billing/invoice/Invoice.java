package com.meterworks.billing.invoice;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

/** What a customer owes for one billing period at one service point. */
@Table("invoices")
public record Invoice(
        @Id UUID id,
        UUID customerId,
        UUID servicePointId,
        LocalDate periodStart,
        LocalDate periodEnd,
        long consumptionWh,
        boolean estimated,
        BigDecimal amount,
        LocalDate issuedOn,
        LocalDate dueOn,
        Status status) {

    public enum Status { ISSUED, PAID, OVERDUE, WRITTEN_OFF }

    public boolean isOverdue(LocalDate today) {
        return status == Status.ISSUED && today.isAfter(dueOn);
    }
}
