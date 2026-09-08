class AddIsFreeToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :is_free, :boolean, default: false, null: false
  end
end