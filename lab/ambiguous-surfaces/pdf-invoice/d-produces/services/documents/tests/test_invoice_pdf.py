import datetime as dt
from types import SimpleNamespace

from pypdf import PdfReader
import io

from documents.invoice_pdf import render_invoice_pdf


class Lines(list):
    def all(self):
        return self


# @gloss verifies hp:Invoice
def test_pdf_carries_the_legally_required_fields():
    inv = SimpleNamespace(
        number="HP-202610-c1", issued_on=dt.date(2026, 10, 5), due_on=dt.date(2026, 11, 4),
        subtotal_cents=48000, tax_cents=435, total_cents=48435,
        lines=Lines([SimpleNamespace(description="Paper napkins", cases=4, unit_cents=1500, taxable=True)]),
    )
    text = PdfReader(io.BytesIO(render_invoice_pdf(inv))).pages[0].extract_text()
    for required in ("INVOICE HP-202610-c1", "Seller's permit 102-448871", "Due November 04, 2026", "Total due", "$484.35"):
        assert required in text
