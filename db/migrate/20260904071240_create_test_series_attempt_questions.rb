class CreateTestSeriesAttemptQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_attempt_questions do |t|
      t.references :test_series_attempt, null: false, foreign_key: true
      t.references :test_series_question, null: false, foreign_key: true
      t.boolean :bookmarked

      t.timestamps
    end
  end
end
