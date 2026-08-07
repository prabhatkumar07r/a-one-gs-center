class AddStatusToEnrollment < ActiveRecord::Migration[8.1]
  def change
    add_column :enrollments, :status, :string
  end
end
