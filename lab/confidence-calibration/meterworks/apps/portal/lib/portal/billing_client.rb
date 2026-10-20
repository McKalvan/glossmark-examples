require "faraday"
require "json"

module Portal
  # Talks to the billing service's invoice API.
  class BillingClient
    Invoice = Struct.new(:id, :period_start, :period_end, :consumption_kwh, :estimated, :amount, :due_on, :status,
                         keyword_init: true)

    def initialize(base_url: ENV.fetch("BILLING_URL"))
      @http = Faraday.new(url: base_url) { |f| f.response :raise_error }
    end

    def invoices(customer_id)
      JSON.parse(@http.get("/v1/customers/#{customer_id}/invoices").body).map { |h| to_invoice(h) }
    end

    def invoice(customer_id, invoice_id)
      to_invoice(JSON.parse(@http.get("/v1/customers/#{customer_id}/invoices/#{invoice_id}").body))
    rescue Faraday::ResourceNotFound
      nil
    end

    private

    def to_invoice(h)
      Invoice.new(id: h["id"], period_start: h["periodStart"], period_end: h["periodEnd"],
                  consumption_kwh: h["consumptionKwh"], estimated: h["estimated"], amount: h["amount"],
                  due_on: h["dueOn"], status: h["status"])
    end
  end
end
