class AddDetailsToTeachers < ActiveRecord::Migration[8.1]
  def change
    add_column :teachers, :name, :string
    add_column :teachers, :email, :string
    add_column :teachers, :mobile, :string
    add_column :teachers, :qualification, :string
    add_column :teachers, :subject, :string
    add_column :teachers, :experience, :integer
    add_column :teachers, :salary, :decimal
    add_column :teachers, :joining_date, :date
    add_column :teachers, :status, :string
  end
end
