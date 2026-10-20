package com.meterworks.billing.invoice;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** Test double: a map instead of Postgres. Only the methods the tests reach are real. */
class InMemoryInvoiceRepository implements InvoiceRepository {
    final Map<UUID, Invoice> invoices = new LinkedHashMap<>();

    @Override
    public <S extends Invoice> S save(S invoice) {
        invoices.put(invoice.id(), invoice);
        return invoice;
    }

    @Override
    public Optional<Invoice> findById(UUID id) {
        return Optional.ofNullable(invoices.get(id));
    }

    @Override
    public List<Invoice> findByCustomerIdOrderByIssuedOnDesc(UUID customerId) {
        return invoices.values().stream()
                .filter(i -> i.customerId().equals(customerId))
                .sorted(Comparator.comparing(Invoice::issuedOn).reversed())
                .toList();
    }

    @Override
    public List<Invoice> findUnpaidPastDue(LocalDate today) {
        return invoices.values().stream().filter(i -> i.isOverdue(today)).toList();
    }

    @Override
    public boolean existsByServicePointIdAndPeriodStart(UUID servicePointId, LocalDate periodStart) {
        return invoices.values().stream()
                .anyMatch(i -> i.servicePointId().equals(servicePointId) && i.periodStart().equals(periodStart));
    }

    @Override
    public <S extends Invoice> Iterable<S> saveAll(Iterable<S> entities) {
        List<S> out = new ArrayList<>();
        entities.forEach(e -> out.add(save(e)));
        return out;
    }

    @Override
    public boolean existsById(UUID id) {
        return invoices.containsKey(id);
    }

    @Override
    public Iterable<Invoice> findAll() {
        return invoices.values();
    }

    @Override
    public Iterable<Invoice> findAllById(Iterable<UUID> ids) {
        List<Invoice> out = new ArrayList<>();
        ids.forEach(id -> findById(id).ifPresent(out::add));
        return out;
    }

    @Override
    public long count() {
        return invoices.size();
    }

    @Override
    public void deleteById(UUID id) {
        invoices.remove(id);
    }

    @Override
    public void delete(Invoice entity) {
        invoices.remove(entity.id());
    }

    @Override
    public void deleteAllById(Iterable<? extends UUID> ids) {
        ids.forEach(invoices::remove);
    }

    @Override
    public void deleteAll(Iterable<? extends Invoice> entities) {
        entities.forEach(this::delete);
    }

    @Override
    public void deleteAll() {
        invoices.clear();
    }
}
