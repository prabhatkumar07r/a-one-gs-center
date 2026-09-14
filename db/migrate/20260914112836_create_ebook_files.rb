class CreateEbookFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :ebook_files do |t|
      t.references :ebook, null: false, foreign_key: true

      t.string :title, null: false
      t.text :description

      t.integer :position, null: false, default: 1

      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :ebook_files,
              [:ebook_id, :position],
              unique: true

    add_index :ebook_files,
              [:ebook_id, :status]
  end
end