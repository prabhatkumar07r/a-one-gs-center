class CreateBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :batches do |t|
      t.string :batch_name
      t.references :course, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.string :timing
      t.string :room_no
      t.string :status

      t.timestamps
    end
  end
end
