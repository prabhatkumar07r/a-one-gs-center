class AddPositionToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :position, :integer,default:1,null:false
  end
end
