import io

from reportlab.lib.pagesizes import LETTER
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

SELLER = ("Harbor Provisions Inc.", "41 Pier Road, Oakland CA 94607", "Seller's permit 102-448871")


def _cents(value):
    return f"${value / 100:,.2f}"


# @gloss presents hp:Invoice
def render_invoice_pdf(invoice) -> bytes:
    """The PDF we send and archive. It is the invoice of record; the tax authority sees this, not the database."""
    buf = io.BytesIO()
    pdf = canvas.Canvas(buf, pagesize=LETTER)
    y = 10.2 * inch
    for line in SELLER:
        pdf.drawString(0.75 * inch, y, line)
        y -= 14
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawRightString(7.75 * inch, 10.2 * inch, f"INVOICE {invoice.number}")
    pdf.setFont("Helvetica", 10)
    pdf.drawRightString(7.75 * inch, 10.0 * inch, f"Issued {invoice.issued_on:%B %d, %Y}")
    pdf.drawRightString(7.75 * inch, 9.85 * inch, f"Due {invoice.due_on:%B %d, %Y}")

    y = 9.2 * inch
    for item in invoice.lines.all():
        amount = item.cases * item.unit_cents
        pdf.drawString(0.75 * inch, y, item.description + (" *" if item.taxable else ""))
        pdf.drawRightString(5.5 * inch, y, f"{item.cases} x {_cents(item.unit_cents)}")
        pdf.drawRightString(7.75 * inch, y, _cents(amount))
        y -= 16
    y -= 10
    for label, value in (("Subtotal", invoice.subtotal_cents), ("Sales tax (* taxable)", invoice.tax_cents), ("Total due", invoice.total_cents)):
        pdf.drawRightString(5.5 * inch, y, label)
        pdf.drawRightString(7.75 * inch, y, _cents(value))
        y -= 16
    pdf.showPage()
    pdf.save()
    return buf.getvalue()
