
class CreateBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :banners do |t|
      t.string :title, null: false
      t.string :subtitle
      t.string :button_text
      t.string :button_url
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :banners, [:active, :position]
  end
end