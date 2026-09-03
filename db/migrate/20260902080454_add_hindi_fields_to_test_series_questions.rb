class AddHindiFieldsToTestSeriesQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :test_series_questions, :question_text_hindi, :text
    add_column :test_series_questions, :explanation_hindi, :text
  end
end
