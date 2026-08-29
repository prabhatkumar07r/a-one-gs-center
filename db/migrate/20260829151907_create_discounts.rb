class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string :name
      t.string :discount_type
      t.decimal :discount_value
      t.date :start_date
      t.date :end_date
      t.string :status

      t.timestamps
    end
  end
end
