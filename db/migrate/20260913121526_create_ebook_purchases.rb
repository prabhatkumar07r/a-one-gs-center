class CreateEbookPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :ebook_purchases do |t|
      t.references :ebook, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount
      t.string :payment_status
      t.string :status
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.string :razorpay_signature

      t.timestamps
    end
  end
end
