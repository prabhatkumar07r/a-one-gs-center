class CreateEbooks < ActiveRecord::Migration[8.1]
  def change
    create_table :ebooks do |t|
      t.string :title, null: false
      t.text :description

      t.string :author
      t.string :category
      t.string :language
      t.string :exam_name

      t.decimal :price, precision: 10, scale: 2, default: 0
      t.decimal :original_price, precision: 10, scale: 2, default: 0
      t.decimal :discount_percentage, precision: 5, scale: 2, default: 0

      t.boolean :is_free, default: true, null: false

      t.string :status, default: "draft", null: false

      t.datetime :published_at

      t.timestamps
    end
  end
end
