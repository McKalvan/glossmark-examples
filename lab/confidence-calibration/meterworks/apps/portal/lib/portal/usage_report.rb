require "date"

module Portal
  # Daily consumption for a customer's meters, from the half-hourly register reads.
  class UsageReport
    Day = Struct.new(:date, :kwh)

    def initialize(conn)
      @conn = conn
    end

    def for_customer(customer_id, days: 30)
      since = Date.today - days
      rows = @conn.exec_params(<<~SQL, [customer_id, since])
        SELECT r.read_at::date AS day, max(r.cumulative_wh) - min(r.cumulative_wh) AS wh
        FROM meter_readings r
        JOIN meters m ON m.serial = r.meter_serial
        JOIN service_points sp ON sp.id = m.service_point_id
        WHERE sp.customer_id = $1 AND r.read_at >= $2
        GROUP BY 1 ORDER BY 1
      SQL
      rows.map { |row| Day.new(Date.parse(row["day"]), row["wh"].to_i / 1000.0) }
    end

    def self.total_kwh(days)
      days.sum(&:kwh).round(1)
    end
  end
end
