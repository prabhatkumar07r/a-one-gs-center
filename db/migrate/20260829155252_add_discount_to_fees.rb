class AddDiscountToFees < ActiveRecord::Migration[8.1]
  def change
    add_column :fees, :discount_amount, :decimal
    add_column :fees, :discount_name, :string
  end
end
