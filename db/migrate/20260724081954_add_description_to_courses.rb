class AddDescriptionToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :description, :text
  end
end
