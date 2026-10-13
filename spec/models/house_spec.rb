require "rails_helper"

RSpec.describe House, type: :model do
  describe "validations" do
    it "is valid with a name" do
      house = House.new(name: "Solar House")

      expect(house).to be_valid
    end

    it "requires a name" do
      house = House.new(name: nil)

      expect(house).not_to be_valid
      expect(house.errors[:name]).to include("can't be blank")
    end
  end
end