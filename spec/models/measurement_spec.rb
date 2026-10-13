
require "rails_helper"

RSpec.describe Measurement, type: :model do
  let(:house) { House.create!(name: "Solar House") }
  let(:consumer) { Consumer.create!(name: "Apartment 1", house: house) }

  let(:location) do
    Location.create!(
      consumer: consumer,
      location_type: "market",
      external_id: "1234567890"
    )
  end

  let(:starts_at) { Time.zone.parse("2026-06-04 10:00:00") }
  let(:ends_at) { starts_at + 15.minutes }

  def build_measurement(attributes = {})
    Measurement.new(
      {
        location: location,
        starts_at: starts_at,
        ends_at: ends_at,
        value: BigDecimal("0.4861"),
        quality: "TRUE"
      }.merge(attributes)
    )
  end

  describe "validations" do
    it "accepts a valid measurement" do
      expect(build_measurement).to be_valid
    end

    it "requires a location" do
      expect(build_measurement(location: nil)).not_to be_valid
    end

    it "requires a value" do
      expect(build_measurement(value: nil)).not_to be_valid
    end

    it "accepts a zero value" do
      expect(build_measurement(value: 0)).to be_valid
    end

    it "requires interval timestamps" do
      expect(build_measurement(starts_at: nil)).not_to be_valid
      expect(build_measurement(ends_at: nil)).not_to be_valid
    end

    it "rejects an end time before its start time" do
      measurement = build_measurement(ends_at: starts_at - 15.minutes)

      expect(measurement).not_to be_valid
      expect(measurement.errors[:ends_at]).not_to be_empty
    end

    it "rejects a zero-duration interval" do
      measurement = build_measurement(ends_at: starts_at)

      expect(measurement).not_to be_valid
    end

    it "rejects a duplicate measurement interval" do
      build_measurement.save!

      duplicate = build_measurement

      expect {
        duplicate.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same interval for different locations" do
      other_location = Location.create!(
        consumer: consumer,
        location_type: "metering",
        external_id: "DE0000000000000000000000000000000"
      )

      build_measurement.save!

      other_measurement = build_measurement(location: other_location)

      expect(other_measurement).to be_valid
      expect { other_measurement.save! }.not_to raise_error
    end
  end
end
