package com.meterworks.billing.invoice;

import java.util.List;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/v1/customers/{customerId}/invoices")
public class InvoiceController {
    private final InvoiceRepository invoices;

    public InvoiceController(InvoiceRepository invoices) {
        this.invoices = invoices;
    }

    @GetMapping
    public List<InvoiceDto> list(@PathVariable UUID customerId) {
        return invoices.findByCustomerIdOrderByIssuedOnDesc(customerId).stream().map(InvoiceDto::from).toList();
    }

    @GetMapping("/{invoiceId}")
    public ResponseEntity<InvoiceDto> get(@PathVariable UUID customerId, @PathVariable UUID invoiceId) {
        return invoices.findById(invoiceId)
                .filter(i -> i.customerId().equals(customerId))
                .map(InvoiceDto::from)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
