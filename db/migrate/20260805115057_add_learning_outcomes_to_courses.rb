class AddLearningOutcomesToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :learning_outcomes, :text
  end
end
