class AddCouponAmountsToEnrollments < ActiveRecord::Migration[8.1]
  def change
    add_reference :enrollments,
                  :coupon,
                  null: true,
                  foreign_key: true

    add_column :enrollments,
                :discount_amount,
                :decimal,
                precision: 10,
                scale: 2

    add_column :enrollments,
                :original_amount,
                :decimal,
                precision: 10,
                scale: 2

    add_column :enrollments,
                :final_amount,
                :decimal,
                precision: 10,
                scale: 2
  end
end