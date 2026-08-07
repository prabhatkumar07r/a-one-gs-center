class AddPricingToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :original_fee, :decimal
    add_column :courses, :discount_percentage, :integer
  end
end
