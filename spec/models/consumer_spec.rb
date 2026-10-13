require "rails_helper"

RSpec.describe Consumer, type: :model do
  let(:house) { House.create!(name: "Solar House") }

  describe "validations" do
    it "is valid with a name and house" do
      consumer = Consumer.new(
        name: "Apartment 1",
        house: house
      )

      expect(consumer).to be_valid
    end

    it "requires a house" do
      consumer = Consumer.new(name: "Apartment 1")

      expect(consumer).not_to be_valid
    end

    it "requires a name" do
      consumer = Consumer.new(house: house)

      expect(consumer).not_to be_valid
    end
  end
end