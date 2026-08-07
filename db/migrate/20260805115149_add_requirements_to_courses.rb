class AddRequirementsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :requirements, :text
  end
end
