# Billing runbook

## The monthly invoice run

`InvoiceRun.runForPreviousMonth` fires at 03:00 on the 1st (Europe/London) and
issues one invoice per active service point. It is idempotent per service point
and month: rerun it by restarting the `billing` Deployment after 03:00.

## Estimated bills

A period with no actual read in the last 35 days (`billing.estimate-after-days`)
is billed on an estimate. Customers can correct it by sending a reading from the
portal; the next invoice reconciles the difference.

## Dunning

Invoices unpaid 14 days after issue (`billing.payment-terms-days`) are marked
overdue at 06:30 and a reminder letter request goes to `billing.dunning.v1`.
Changing the payment terms is a regulatory change: talk to compliance first.
