class AddTestSeriesToQuizzes < ActiveRecord::Migration[8.1]
  def change
    add_reference :quizzes, :test_series, null: true, foreign_key: true
  end
end