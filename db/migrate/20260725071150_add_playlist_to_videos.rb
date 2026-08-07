class AddPlaylistToVideos < ActiveRecord::Migration[8.1]
  def change
    add_reference :videos, :playlist,foreign_key: true
  end
end
