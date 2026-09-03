class AddCompletedAtToTestSeriesAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :test_series_attempts, :completed_at, :datetime
  end
end
