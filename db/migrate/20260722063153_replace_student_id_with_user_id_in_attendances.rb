class ReplaceStudentIdWithUserIdInAttendances < ActiveRecord::Migration[8.1]
  def change
    remove_reference :attendances, :student, foreign_key: true
    add_reference :attendances, :user, foreign_key: true
  end
end
