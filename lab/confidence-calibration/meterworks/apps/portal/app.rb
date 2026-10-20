require "sinatra/base"
require "pg"
require_relative "lib/portal/billing_client"
require_relative "lib/portal/usage_report"
require_relative "lib/portal/session"

module Portal
  # The customer self-service site: half-hourly usage and invoices.
  class App < Sinatra::Base
    set :views, File.join(__dir__, "views")

    helpers do
      def current_customer_id
        Session.customer_id(request) or halt 401
      end

      def readings_db
        @readings_db ||= PG.connect(ENV.fetch("READINGS_DATABASE_URL"))
      end
    end

    get "/usage" do
      report = UsageReport.new(readings_db).for_customer(current_customer_id, days: Integer(params.fetch("days", 30)))
      erb :usage, locals: { report: report }
    end

    get "/invoices" do
      invoices = BillingClient.new.invoices(current_customer_id)
      erb :invoices, locals: { invoices: invoices }
    end

    get "/invoices/:id" do
      invoice = BillingClient.new.invoice(current_customer_id, params[:id]) or halt 404
      erb :invoice, locals: { invoice: invoice }
    end

    get "/healthz" do
      "ok"
    end
  end
end
