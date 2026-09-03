class CreateTestSeriesOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :test_series_options do |t|
      t.references :test_series_question,
                   null: false,
                   foreign_key: true

      t.string :option_text,
                  null: false

      t.boolean :is_correct,
                default: false,
                null: false

      t.integer :position,
                  default: 1,
                  null: false

      t.timestamps
    end

    add_index :test_series_options,
              [:test_series_question_id, :position],
              unique: true
  end
end