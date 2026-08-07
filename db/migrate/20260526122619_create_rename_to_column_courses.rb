class CreateRenameToColumnCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :rename_to_column_courses do |t|
      rename_column:courses,:name, :Course_name
        
      t.timestamps
    end
  end
end
