class AddColumnToTeacher < ActiveRecord::Migration[8.1]
  def change
    add_column:teachers,:age,:integer
    add_column:teachers,:Contact_number,:integer
  end
end
