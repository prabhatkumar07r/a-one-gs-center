class AddNotificationSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_notifications, :boolean
    add_column :users, :system_notifications, :boolean
    add_column :users, :student_notifications, :boolean
    add_column :users, :teacher_notifications, :boolean
  end
end
