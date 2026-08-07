class AddFieldsToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :video_url, :string
    add_column :videos, :thumbnail, :string
    add_column :videos, :status, :integer,default:1
  end
end
