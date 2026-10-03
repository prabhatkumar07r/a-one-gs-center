class AddEbookIdToCoupons < ActiveRecord::Migration[8.1]
  def change
    add_reference :coupons, :ebook, null: true, foreign_key: true
  end
end