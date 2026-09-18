class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons do |t|
      t.string :code, null: false

      t.string :coupon_type,
               null: false,
               default: "everyone"

      t.references :student,
                   null: true,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :discount_type,
               null: false,
               default: "percentage"

      t.decimal :discount_value,
                  precision: 10,
                  scale: 2,
                  null: false

      t.integer :usage_limit

      t.integer :used_count,
                null: false,
                default: 0

      t.datetime :expires_at

      t.boolean :active,
                 null: false,
                 default: true

      t.references :course,
                   null: false,
                   foreign_key: true

      t.timestamps
    end

    add_index :coupons, :code, unique: true
  end
end