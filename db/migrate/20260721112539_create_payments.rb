class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.decimal :amount
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.string :razorpay_signature
      t.string :status

      t.timestamps
    end
  end
end
