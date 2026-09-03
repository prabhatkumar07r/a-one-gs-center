class CreateTestSeriesAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :test_series_test, null: false, foreign_key: true
      t.integer :score
      t.integer :total_marks
      t.datetime :started_at
      t.datetime :submitted_at
      t.string :status

      t.timestamps
    end
  end
end
