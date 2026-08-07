class AddUserToTeachers < ActiveRecord::Migration[8.1]
  def change
    add_reference :teachers, :user, null: true, foreign_key: true
  end
end
