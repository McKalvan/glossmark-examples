package com.meterworks.billing.invoice;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;

public interface InvoiceRepository extends CrudRepository<Invoice, UUID> {

    List<Invoice> findByCustomerIdOrderByIssuedOnDesc(UUID customerId);

    @Query("SELECT * FROM invoices WHERE status = 'ISSUED' AND due_on < :today")
    List<Invoice> findUnpaidPastDue(LocalDate today);

    boolean existsByServicePointIdAndPeriodStart(UUID servicePointId, LocalDate periodStart);
}
