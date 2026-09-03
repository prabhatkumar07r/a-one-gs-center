class CreateQuizzes < ActiveRecord::Migration[8.1]
  def change
    create_table :quizzes do |t|
      t.references :course, null: false, foreign_key: true

      t.string :title, null: false
      t.text :description

      t.integer :time_limit, default: 30, null: false

      t.decimal :passing_percentage,
                precision: 5,
                scale: 2,
                default: 40.0,
                null: false

      t.string :status,
                default: "Active",
                null: false

      t.timestamps
    end

    add_index :quizzes, [:course_id, :title], unique: true
  end
end