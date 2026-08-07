class AddVideoToNotes < ActiveRecord::Migration[8.1]
  def change
    add_reference :notes, :video,  foreign_key: true
  end
end
