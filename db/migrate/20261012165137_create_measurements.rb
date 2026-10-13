class CreateMeasurements < ActiveRecord::Migration[8.1]
  def change
    create_table :measurements do |t|
      t.references :location, null: false, foreign_key: true, index: false

      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.decimal :value,
                precision: 12,
                scale: 4,
                null: false

      t.string :quality

      t.timestamps
    end

    add_index :measurements,
              [:location_id, :starts_at, :ends_at],
              unique: true,
              name: "idx_measurements_unique_interval"

    add_check_constraint :measurements,
                         "ends_at > starts_at",
                         name: "measurements_valid_interval"
  end
end