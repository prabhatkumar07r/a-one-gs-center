class AddAnswerDetailsToQuizAnswers < ActiveRecord::Migration[8.1]
  def change
    add_column :quiz_answers, :selected_text, :text
    add_column :quiz_answers, :is_correct, :boolean
  end
end
