
require "rails_helper"

RSpec.describe Location, type: :model do
  let(:house) { House.create!(name: "Solar House") }
  let(:consumer) { Consumer.create!(name: "Apartment 1", house: house) }

  describe "validations" do
    it "accepts a valid market location" do
      location = Location.new(
        consumer: consumer,
        location_type: "market",
        external_id: "1234567890"
      )

      expect(location).to be_valid
    end

    it "accepts a valid metering location" do
      location = Location.new(
        consumer: consumer,
        location_type: "metering",
        external_id: "DE0000000000000000000000000000000"
      )

      expect(location).to be_valid
    end

    it "rejects market IDs that are not exactly 10 digits" do
      location = Location.new(
        consumer: consumer,
        location_type: "market",
        external_id: "12345"
      )

      expect(location).not_to be_valid
      expect(location.errors[:external_id]).not_to be_empty
    end

    it "rejects metering IDs that are not 33 characters" do
      location = Location.new(
        consumer: consumer,
        location_type: "metering",
        external_id: "DE123"
      )

      expect(location).not_to be_valid
      expect(location.errors[:external_id]).not_to be_empty
    end

    it "rejects unsupported location types" do
      location = Location.new(
        consumer: consumer,
        location_type: "solar",
        external_id: "1234567890"
      )

      expect(location).not_to be_valid
    end

    it "allows one market and one metering location per consumer" do
      Location.create!(
        consumer: consumer,
        location_type: "market",
        external_id: "1234567890"
      )

      location = Location.new(
        consumer: consumer,
        location_type: "metering",
        external_id: "DE0000000000000000000000000000000"
      )

      expect(location).to be_valid
    end

    it "does not allow two market locations for one consumer" do
      Location.create!(
        consumer: consumer,
        location_type: "market",
        external_id: "1234567890"
      )

      duplicate = Location.new(
        consumer: consumer,
        location_type: "market",
        external_id: "9876543210"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:location_type]).not_to be_empty
    end

    it "does not allow duplicate external IDs" do
      Location.create!(
        consumer: consumer,
        location_type: "market",
        external_id: "1234567890"
      )

      another_consumer = Consumer.create!(
        name: "Apartment 2",
        house: house
      )

      duplicate = Location.new(
        consumer: another_consumer,
        location_type: "market",
        external_id: "1234567890"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).not_to be_empty
    end
  end
end
