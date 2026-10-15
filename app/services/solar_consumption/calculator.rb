
module SolarConsumption
  class Calculator
    ZERO = BigDecimal("0")

    def call(house:, from_date:, to_date:)
      raise ArgumentError, "Invalid date range" if to_date < from_date

      consumers = house.consumers.includes(:locations)

      consumer_summaries = consumers.map do |consumer|
        calculate_consumer(consumer, from_date, to_date)
      end

      house_daily_totals = Hash.new(ZERO)

      consumer_summaries.each do |summary|
        summary[:daily_totals].each do |date, value|
          house_daily_totals[date] += value
        end
      end

      {
        house: house,
        from_date: from_date,
        to_date: to_date,
        consumers: consumer_summaries,
        **summarize(house_daily_totals)
      }
    end

    private

      def calculate_consumer(consumer, from_date, to_date)
        locations = consumer.locations.index_by(&:location_type)

        market = locations["market"]
        metering = locations["metering"]

        daily_totals = Hash.new(ZERO)

        if market && metering
          matched_readings(market, metering, from_date, to_date).each do |starts_at, metering_value, market_value|
            date = starts_at.in_time_zone.to_date
            daily_totals[date] += metering_value - market_value
          end
        end

        {
          consumer: consumer,
          **summarize(daily_totals)
        }
      end

      def matched_readings(market, metering, from_date, to_date)
        # Join measurements on matching time intervals.
        join_sql = Measurement.sanitize_sql_array([
          <<~SQL,
          INNER JOIN measurements AS market_readings
            ON market_readings.location_id = ?
           AND market_readings.starts_at = measurements.starts_at
           AND market_readings.ends_at = measurements.ends_at
        SQL
          market.id
        ])

        start_time = from_date.in_time_zone.beginning_of_day
        end_time = (to_date + 1.day).in_time_zone.beginning_of_day

        Measurement
          .where(location_id: metering.id)
          .where(starts_at: start_time...end_time)
          .joins(join_sql)
          .pluck(
            Arel.sql("measurements.starts_at"),
            Arel.sql("measurements.value"),
            Arel.sql("market_readings.value")
          )
      end

      def summarize(daily_totals)
        total = daily_totals.values.sum(ZERO)
        day_count = daily_totals.size

        {
          total: total,
          average_daily: day_count.zero? ? ZERO : total / day_count,
          days_with_data: day_count,
          daily_totals: daily_totals.sort.to_h
        }
      end
  end
end
