class AddToStudentNameToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :student_name, :string
  end
end
