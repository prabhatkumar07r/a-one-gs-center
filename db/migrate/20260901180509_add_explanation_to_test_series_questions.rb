class AddExplanationToTestSeriesQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :test_series_questions, :explanation, :text
  end
end
