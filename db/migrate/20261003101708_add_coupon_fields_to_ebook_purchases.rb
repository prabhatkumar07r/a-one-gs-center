class AddCouponFieldsToEbookPurchases < ActiveRecord::Migration[8.1]
  def change
    add_reference :ebook_purchases,
                  :coupon,
                  null: true,
                  foreign_key: true

    add_column :ebook_purchases,
               :original_amount,
               :decimal,
               precision: 10,
               scale: 2,
               null: true

    add_column :ebook_purchases,
               :discount_amount,
               :decimal,
               precision: 10,
               scale: 2,
               null: false,
               default: 0

    add_column :ebook_purchases,
               :final_amount,
               :decimal,
               precision: 10,
               scale: 2,
               null: true
  end
end