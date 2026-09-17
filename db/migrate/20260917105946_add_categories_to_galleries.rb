class AddCategoriesToGalleries < ActiveRecord::Migration[8.1]
  def change
    add_column :galleries, :categories, :text, array: true, default: [], null: false
  end
end