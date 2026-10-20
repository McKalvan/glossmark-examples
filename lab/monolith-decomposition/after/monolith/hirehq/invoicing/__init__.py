from django.conf import settings

from .client import InvoicingClient


def issue_invoice(hire):
    return InvoicingClient(settings.INVOICING_SERVICE_URL).issue(hire)
