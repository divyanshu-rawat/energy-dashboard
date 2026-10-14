
require "rails_helper"

RSpec.describe SolarConsumption::Calculator do
  let(:house) { House.create!(name: "Solar House") }
  let(:consumer) { Consumer.create!(house: house, name: "Apartment 1") }

  let(:market) do
    Location.create!(
      consumer: consumer,
      location_type: "market",
      external_id: "1234567890"
    )
  end

  let(:metering) do
    Location.create!(
      consumer: consumer,
      location_type: "metering",
      external_id: "DE0000000000000000000000000000000"
    )
  end

  let(:calculator) { described_class.new }
  let(:day_one) { Date.new(2026, 6, 4) }
  let(:day_two) { Date.new(2026, 6, 5) }

  def add_reading(location, time, value)
    Measurement.create!(
      location: location,
      starts_at: Time.iso8601(time),
      ends_at: Time.iso8601(time) + 15.minutes,
      value: BigDecimal(value),
      quality: "TRUE"
    )
  end

  def calculate(from_date: day_one, to_date: day_two)
    calculator.call(
      house: house,
      from_date: from_date,
      to_date: to_date
    )
  end

  it "calculates solar consumption from matching intervals" do
    add_reading(metering, "2026-06-04T10:00:00+02:00", "1.2")
    add_reading(market, "2026-06-04T10:00:00+02:00", "0.4")

    add_reading(metering, "2026-06-04T10:15:00+02:00", "1.5")
    add_reading(market, "2026-06-04T10:15:00+02:00", "0.6")

    result = calculate

    expect(result[:total]).to eq(BigDecimal("1.7"))
    expect(result[:average_daily]).to eq(BigDecimal("1.7"))
    expect(result[:days_with_data]).to eq(1)

    expect(result[:consumers].first[:total]).to eq(BigDecimal("1.7"))
  end

  it "excludes intervals without a matching reading" do
    add_reading(metering, "2026-06-04T10:00:00+02:00", "1.2")
    add_reading(market, "2026-06-04T10:00:00+02:00", "0.4")

    # No matching market reading for this interval.
    add_reading(metering, "2026-06-04T10:15:00+02:00", "5.0")

    expect(calculate[:total]).to eq(BigDecimal("0.8"))
  end

  it "calculates the average across days with data" do
    add_reading(metering, "2026-06-04T10:00:00+02:00", "3.0")
    add_reading(market, "2026-06-04T10:00:00+02:00", "1.0")

    add_reading(metering, "2026-06-05T10:00:00+02:00", "5.0")
    add_reading(market, "2026-06-05T10:00:00+02:00", "1.0")

    result = calculate

    expect(result[:total]).to eq(BigDecimal("6.0"))
    expect(result[:average_daily]).to eq(BigDecimal("3.0"))
    expect(result[:days_with_data]).to eq(2)
  end

  it "respects the requested date range" do
    add_reading(metering, "2026-06-04T10:00:00+02:00", "3.0")
    add_reading(market, "2026-06-04T10:00:00+02:00", "1.0")

    add_reading(metering, "2026-06-05T10:00:00+02:00", "5.0")
    add_reading(market, "2026-06-05T10:00:00+02:00", "1.0")

    result = calculate(from_date: day_one, to_date: day_one)

    expect(result[:total]).to eq(BigDecimal("2.0"))
  end

  it "returns zero when there are no measurements" do
    result = calculate

    expect(result[:total]).to eq(BigDecimal("0"))
    expect(result[:average_daily]).to eq(BigDecimal("0"))
    expect(result[:days_with_data]).to eq(0)
  end

  it "sums consumption across consumers in the same house" do
    add_reading(metering, "2026-06-04T10:00:00+02:00", "3.0")
    add_reading(market, "2026-06-04T10:00:00+02:00", "1.0")

    second = Consumer.create!(house: house, name: "Apartment 2")

    second_market = Location.create!(
      consumer: second,
      location_type: "market",
      external_id: "9876543210"
    )

    second_metering = Location.create!(
      consumer: second,
      location_type: "metering",
      external_id: "DE1111111111111111111111111111111"
    )

    add_reading(second_metering, "2026-06-04T10:00:00+02:00", "4.0")
    add_reading(second_market, "2026-06-04T10:00:00+02:00", "1.0")

    result = calculate

    expect(result[:consumers].size).to eq(2)
    expect(result[:total]).to eq(BigDecimal("5.0"))
    expect(result[:average_daily]).to eq(BigDecimal("5.0"))
  end

  it "rejects an invalid date range" do
    expect {
      calculate(from_date: day_two, to_date: day_one)
    }.to raise_error(ArgumentError, "Invalid date range")
  end
end
