class AddPasswordToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :password, :string
  end
end
