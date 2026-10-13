class CreateConsumers < ActiveRecord::Migration[8.1]
  def change
    create_table :consumers do |t|
      t.string :name, null: false
      t.references :house, null: false, foreign_key: true

      t.timestamps
    end
  end
end