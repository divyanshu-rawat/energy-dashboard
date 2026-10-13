
require "rails_helper"

RSpec.describe Measurements::Importer do
  let(:house) { House.create!(name: "Solar House") }
  let(:consumer) { Consumer.create!(name: "Apartment 1", house: house) }

  let!(:market) do
    Location.create!(
      consumer: consumer,
      location_type: "market",
      external_id: "1234567890"
    )
  end

  let!(:metering) do
    Location.create!(
      consumer: consumer,
      location_type: "metering",
      external_id: "DE0000000000000000000000000000000"
    )
  end

  let(:api_client) { instance_double(Measurements::ApiClient) }
  let(:importer) { described_class.new(api_client: api_client) }
  let(:begin_date) { Date.new(2026, 6, 4) }

  let(:starts_at) { Time.iso8601("2026-06-04T10:00:00+02:00") }
  let(:ends_at) { starts_at + 15.minutes }

  let(:market_readings) do
    [{
      starts_at: starts_at,
      ends_at: ends_at,
      value: BigDecimal("0.4"),
      quality: "TRUE"
    }]
  end

  let(:metering_readings) do
    [{
      starts_at: starts_at,
      ends_at: ends_at,
      value: BigDecimal("1.2"),
      quality: "TRUE"
    }]
  end

  before do
    allow(api_client).to receive(:fetch)
      .with(location_id: market.external_id, begin_date: begin_date)
      .and_return(market_readings)

    allow(api_client).to receive(:fetch)
      .with(location_id: metering.external_id, begin_date: begin_date)
      .and_return(metering_readings)
  end

  def perform_import
    importer.call(consumer: consumer, begin_date: begin_date)
  end

  describe "#call" do
    it "imports measurements for both locations" do
      expect { perform_import }
        .to change(Measurement, :count).by(2)

      expect(market.measurements.first.value)
        .to eq(BigDecimal("0.4"))

      expect(metering.measurements.first.value)
        .to eq(BigDecimal("1.2"))
    end

    it "returns the number of processed readings" do
      expect(perform_import).to eq(2)
    end

    it "does not duplicate measurements on repeated imports" do
      perform_import

      expect { perform_import }
        .not_to change(Measurement, :count)

      expect(Measurement.count).to eq(2)
    end

    it "preserves existing values when the API returns different data" do
      perform_import

      market_readings.first[:value] = BigDecimal("0.9")

      perform_import

      expect(market.measurements.first.reload.value)
        .to eq(BigDecimal("0.4"))

      expect(Measurement.count).to eq(2)
    end

    it "does not persist data if the second API request fails" do
      allow(api_client).to receive(:fetch)
        .with(location_id: metering.external_id, begin_date: begin_date)
        .and_raise(Measurements::ApiClient::Error, "API unavailable")

      expect { perform_import }
        .to raise_error(Measurements::ApiClient::Error)

      expect(Measurement.count).to eq(0)
    end

    it "requires both location types" do
      metering.destroy!

      expect { perform_import }
        .to raise_error(
          Measurements::Importer::Error,
          /both market and metering/
        )
    end

    it "rejects invalid intervals without saving measurements" do
      market_readings.first[:ends_at] = starts_at - 15.minutes

      expect { perform_import }
        .to raise_error(
          Measurements::Importer::Error,
          /Invalid measurement/
        )

      expect(Measurement.count).to eq(0)
    end

    it "allows new intervals while preserving previously imported ones" do
      perform_import

      next_start = ends_at

      market_readings << {
        starts_at: next_start,
        ends_at: next_start + 15.minutes,
        value: BigDecimal("0.5"),
        quality: "TRUE"
      }

      expect { perform_import }
        .to change(Measurement, :count).by(1)

      expect(market.measurements.order(:starts_at).pluck(:value))
        .to eq([BigDecimal("0.4"), BigDecimal("0.5")])
    end
  end
end
