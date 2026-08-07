class CreateVideoProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :video_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :video, null: false, foreign_key: true
      t.boolean :completed

      t.timestamps
    end
  end
end
