class CreateLiveClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :live_classes do |t|
      t.references :course, null: false, foreign_key: true

      t.string :title, null: false
      t.text :description

      t.datetime :scheduled_at
      t.integer :duration

      # Access control
      t.string :access_type, null: false, default: "enrolled"

      # Class status
      t.string :status, null: false, default: "upcoming"

      # Streaming provider
      t.string :provider, null: false, default: "youtube"

      # YouTube URLs
      t.string :stream_url
      t.string :recording_url

      t.timestamps
    end
  end
end