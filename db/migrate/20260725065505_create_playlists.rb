class CreatePlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :playlists do |t|
      t.string :title
      t.text :description
      t.integer :position
      t.references :course, null: false, foreign_key: true

      t.timestamps
    end
  end
end
