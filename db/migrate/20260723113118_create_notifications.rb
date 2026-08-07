class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.string :title
      t.text :description
      t.string :notification_type
      t.string :status
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
