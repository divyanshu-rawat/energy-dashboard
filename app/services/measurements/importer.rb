
module Measurements
  class Importer
    BATCH_SIZE = 1_000

    class Error < StandardError; end

    def initialize(api_client: ApiClient.new)
      @api_client = api_client
    end

    def call(consumer:, begin_date:)
      locations = consumer.locations.index_by(&:location_type)

      market = locations["market"]
      metering = locations["metering"]

      unless market && metering
        raise Error, "Consumer must have both market and metering locations"
      end

      # Fetch both locations before persisting any data.
      profiles = [market, metering].map do |location|
        readings = @api_client.fetch(
          location_id: location.external_id,
          begin_date: begin_date
        )

        [location, build_rows(location, readings)]
      end

      Measurement.transaction do
        profiles.each do |_location, rows|
          rows.each_slice(BATCH_SIZE) do |batch|
            Measurement.insert_all(
              batch,
              unique_by: :idx_measurements_unique_interval,
              record_timestamps: true
            )
          end
        end
      end

      # Number of readings processed, including skipped duplicates.
      profiles.sum { |_location, rows| rows.size }
    end

    private

    def build_rows(location, readings)
      raise Error, "Expected an array of readings" unless readings.is_a?(Array)

      readings.map do |reading|
        starts_at = reading.fetch(:starts_at)
        ends_at = reading.fetch(:ends_at)
        value = reading.fetch(:value)

        unless starts_at.is_a?(Time) &&
              ends_at.is_a?(Time) &&
              ends_at > starts_at &&
              value.is_a?(BigDecimal)
          raise Error, "Invalid measurement interval or value"
        end

        {
          location_id: location.id,
          starts_at: starts_at,
          ends_at: ends_at,
          value: value,
          quality: reading[:quality]
        }
      end
    rescue KeyError, TypeError => e
      raise Error, "Invalid reading: #{e.message}"
    end
  end
end
