class AddSocialFieldsToTeachers < ActiveRecord::Migration[8.1]
  def change
    add_column :teachers, :designation, :string
    add_column :teachers, :bio, :text
    add_column :teachers, :facebook, :string
    add_column :teachers, :instagram, :string
    add_column :teachers, :linkedin, :string
    add_column :teachers, :gmail, :string
  end
end
