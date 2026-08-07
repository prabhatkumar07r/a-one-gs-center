class AddLastWatchedAtToVideoProgresses < ActiveRecord::Migration[8.1]
  def change
    add_column :video_progresses, :last_watched_at, :datetime
  end
end
