class CreateBatchStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_students do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true

      t.timestamps
    end
  end
end
