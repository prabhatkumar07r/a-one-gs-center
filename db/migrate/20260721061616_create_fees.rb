class CreateFees < ActiveRecord::Migration[8.1]
  def change
    create_table :fees do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.decimal :total_fee
      t.decimal :paid_amount
      t.decimal :due_amount
      t.date :payment_date
      t.string :payment_mode
      t.string :receipt_no
      t.string :status

      t.timestamps
    end
  end
end
