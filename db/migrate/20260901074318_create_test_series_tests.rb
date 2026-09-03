class CreateTestSeriesTests < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_tests do |t|
      t.references :test_series, null: false, foreign_key: true

      t.string :title, null: false
      t.text :description

      t.integer :test_number, null: false
      t.integer :duration, default: 30
      t.integer :total_questions, default: 0

      t.decimal :total_marks,
                precision: 8,
                scale: 2,
                default: 0

      t.string :status, default: "Active"

      t.timestamps
    end

    add_index :test_series_tests,
              [:test_series_id, :test_number],
              unique: true
  end
end