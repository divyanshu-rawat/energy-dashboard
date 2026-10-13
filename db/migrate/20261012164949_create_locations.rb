class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :consumer,
                   null: false,
                   foreign_key: true,
                   index: false

      t.string :location_type, null: false
      t.string :external_id, null: false

      t.timestamps
    end

    add_check_constraint :locations,
                         "location_type IN ('market', 'metering')",
                         name: "locations_valid_type"

    add_index :locations,
              [:consumer_id, :location_type],
              unique: true,
              name: "idx_locations_consumer_type"

    add_index :locations,
              :external_id,
              unique: true
  end
end