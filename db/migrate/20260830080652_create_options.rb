class CreateOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :options do |t|
      t.references :question,
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

    add_index :options,
              [:question_id, :position],
              unique: true
  end
end