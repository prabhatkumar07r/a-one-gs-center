class CreateGalleries < ActiveRecord::Migration[8.1]
  def change
    create_table :galleries do |t|
      t.string :title
      t.string :category
      t.text :description
      t.string :status

      t.timestamps
    end
  end
end
