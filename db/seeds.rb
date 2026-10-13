
house = House.find_or_create_by!(name: "Solar House Demo")

consumer = Consumer.find_or_create_by!(
  house: house,
  name: "Apartment 1"
)

[
  {
    location_type: "market",
    external_id: "1234567890"
  },
  {
    location_type: "metering",
    external_id: "DE0000000000000000000000000000000"
  }
].each do |attributes|
  consumer.locations.find_or_create_by!(
    location_type: attributes[:location_type]
  ) do |location|
    location.external_id = attributes[:external_id]
  end
end

puts "Seeded #{House.count} house(s)"
puts "Seeded #{Consumer.count} consumer(s)"
puts "Seeded #{Location.count} location(s)"
