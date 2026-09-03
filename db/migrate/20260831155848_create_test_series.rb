class CreateTestSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series do |t|
      t.string :title
      t.text :description
      t.string :exam_name
      t.string :mode
      t.string :language
      t.decimal :price
      t.decimal :original_price
      t.integer :discount
      t.string :status
      t.boolean :registration_ended

      t.timestamps
    end
  end
end
