class ChangeStudentMobileToString < ActiveRecord::Migration[8.1]
  def change
    change_column :students, :mobile, :string
  end
end