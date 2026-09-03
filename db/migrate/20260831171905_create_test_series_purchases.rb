class CreateTestSeriesPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :test_series, null: false, foreign_key: true
      t.string :payment_status
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.string :razorpay_signature
      t.decimal :amount
      t.string :status

      t.timestamps
    end
  end
end
