class AddPlaylistToLiveClasses < ActiveRecord::Migration[8.1]
  def change
    add_reference :live_classes,
                  :playlist,
                  foreign_key: true,
                  null: true
  end
end