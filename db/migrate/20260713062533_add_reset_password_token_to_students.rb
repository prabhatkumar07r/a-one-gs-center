class AddResetPasswordTokenToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :resets_password_token, :string
  end
end
