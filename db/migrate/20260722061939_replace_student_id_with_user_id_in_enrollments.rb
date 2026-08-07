class ReplaceStudentIdWithUserIdInEnrollments < ActiveRecord::Migration[8.1]
  def change
    remove_reference :enrollments, :student, foreign_key: true
    add_reference :enrollments, :user, foreign_key: true
  end
end
