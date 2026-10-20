require_relative "../lib/portal/usage_report"

RSpec.describe Portal::UsageReport do
  let(:conn) { instance_double("PG::Connection") }

  it "turns register deltas into daily kWh" do
    allow(conn).to receive(:exec_params).and_return([{ "day" => "2026-03-01", "wh" => "8150" }])
    days = described_class.new(conn).for_customer("c-1", days: 7)
    expect(days.first.kwh).to eq(8.15)
  end

  it "totals a period to one decimal place" do
    days = [Portal::UsageReport::Day.new(Date.new(2026, 3, 1), 8.15), Portal::UsageReport::Day.new(Date.new(2026, 3, 2), 7.42)]
    expect(described_class.total_kwh(days)).to eq(15.6)
  end
end
