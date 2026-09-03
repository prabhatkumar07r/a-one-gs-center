class CreateQuizAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_attempts do |t|
      t.references :quiz, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :score
      t.decimal :total_marks
      t.decimal :percentage
      t.string :status
      t.datetime :started_at
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
