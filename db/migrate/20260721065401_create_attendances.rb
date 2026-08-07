class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.references :student, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.date :date
      t.string :status

      t.timestamps
    end
  end
end
