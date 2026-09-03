class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :quiz, null: false, foreign_key: true

      t.text :question_text, null: false

      t.string :question_type,
               default: "multiple_choice",
               null: false

      t.decimal :marks,
                precision: 8,
                scale: 2,
                default: 1.0,
                null: false

      t.integer :position,
                  default: 1,
                  null: false

      t.timestamps
    end

    add_index :questions,
              [:quiz_id, :position],
              unique: true
  end
end