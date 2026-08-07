class AddTeacherToCourses < ActiveRecord::Migration[8.1]
  def change
    add_reference :courses, :teacher, foreign_key: true
  end
end
