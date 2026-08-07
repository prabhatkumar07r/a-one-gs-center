class CreateResources < ActiveRecord::Migration[8.1]
  def change
    create_table :resources do |t|
      t.string :title
      t.text :description
      t.integer :resource_type
      t.references :playlist, null: false, foreign_key: true

      t.timestamps
    end
  end
end
