class AddCourseTypeToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses,
               :course_type,
               :string,
               default: "paid",
               null: false
  end
end