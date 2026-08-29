class CreateFeePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :fee_payments do |t|
      t.references :fee, null: false, foreign_key: true
      t.decimal :amount
      t.date :payment_date
      t.string :payment_mode
      t.string :receipt_no
      t.string :reference_no
      t.text :notes

      t.timestamps
    end
  end
end
