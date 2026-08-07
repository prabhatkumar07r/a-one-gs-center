class AddImageToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :image, :string
  end
end
