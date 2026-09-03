class CreateQuizAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_answers do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.references :option, null: false, foreign_key: true
      t.decimal :marks_obtained

      t.timestamps
    end
  end
end
