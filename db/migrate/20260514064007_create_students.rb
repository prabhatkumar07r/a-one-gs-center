class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :name
      t.string :email
      t.integer :number
      t.integer :age

      t.timestamps
    end
  end
end
