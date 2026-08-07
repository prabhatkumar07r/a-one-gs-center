class AddResetPasswordSentAtToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :resets_password_sent_at, :datetime
  end
end
