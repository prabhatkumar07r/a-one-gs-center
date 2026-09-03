class AddVideoToQuizzes < ActiveRecord::Migration[8.1]
  def change
    add_reference :quizzes, :video,
                  foreign_key: true,
                  null: true
  end
end