class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string :title
      t.text :description
      t.string :subject
      t.string :category
      t.string :file_url
      t.string :file_size
      t.integer :download_count
      t.integer :user_id

      t.timestamps
    end
     # Index for faster searching
    add_index :study_notes, [:category, :subject]
    add_index :study_notes, :user_id
  end
end
