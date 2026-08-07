class AddRoleToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :role, :string
  end
end
