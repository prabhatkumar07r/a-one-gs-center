class RemoveThumbnailFromVideos < ActiveRecord::Migration[8.1]
  def change
    remove_column :videos, :thumbnail, :string
  end
end
