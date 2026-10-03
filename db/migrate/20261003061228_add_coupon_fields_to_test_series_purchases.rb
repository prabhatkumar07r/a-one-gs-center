class AddCouponFieldsToTestSeriesPurchases < ActiveRecord::Migration[8.1]
  def change
    add_reference :test_series_purchases,
                  :coupon,
                  null: true,
                  foreign_key: true

    add_column :test_series_purchases,
                :original_amount,
                :decimal,
                precision: 10,
                scale: 2

    add_column :test_series_purchases,
                :discount_amount,
                :decimal,
                precision: 10,
                scale: 2,
                default: 0,
                null: false

    add_column :test_series_purchases,
                :final_amount,
                :decimal,
                precision: 10,
                scale: 2
  end
end
