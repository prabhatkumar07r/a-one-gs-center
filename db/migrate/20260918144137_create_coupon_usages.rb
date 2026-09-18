class CreateCouponUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :coupon_usages do |t|
      t.references :coupon,
                   null: false,
                   foreign_key: true

      t.references :user,
                   null: false,
                   foreign_key: true

      t.references :enrollment,
                   null: false,
                   foreign_key: true

      t.decimal :discount_amount,
                  precision: 10,
                  scale: 2,
                  null: false

      t.datetime :used_at,
                  null: false

      t.timestamps
    end

    add_index :coupon_usages,
              [:coupon_id, :user_id],
              unique: true
  end
end