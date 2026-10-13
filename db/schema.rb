# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_12_165137) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "consumers", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "house_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_consumers_on_house_id"
  end

  create_table "houses", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.string "location_type", null: false
    t.string "external_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_id", "location_type"], name: "idx_locations_consumer_type", unique: true
    t.index ["external_id"], name: "index_locations_on_external_id", unique: true
    t.check_constraint "location_type::text = ANY (ARRAY['market'::character varying, 'metering'::character varying]::text[])", name: "locations_valid_type"
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.decimal "value", precision: 12, scale: 4, null: false
    t.string "quality"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "starts_at", "ends_at"], name: "idx_measurements_unique_interval", unique: true
    t.check_constraint "ends_at > starts_at", name: "measurements_valid_interval"
  end

  add_foreign_key "consumers", "houses"
  add_foreign_key "locations", "consumers"
  add_foreign_key "measurements", "locations"
end
