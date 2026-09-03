class CreateTestSeriesAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_answers do |t|
      t.references :test_series_attempt, null: false, foreign_key: true
      t.references :test_series_question, null: false, foreign_key: true
      t.references :test_series_option, null: false, foreign_key: true
      t.boolean :is_correct
      t.integer :marks_obtained

      t.timestamps
    end
  end
end
