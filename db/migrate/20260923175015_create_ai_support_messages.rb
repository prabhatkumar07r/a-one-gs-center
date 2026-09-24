class CreateAiSupportMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_support_messages do |t|
      t.references :ai_support_request,
                   null: false,
                   foreign_key: true

      t.references :user,
                   null: false,
                   foreign_key: true

      t.string :sender_type,
                 null: false

      t.text :content,
               null: false

      t.datetime :read_at

      t.timestamps
    end

    add_index :ai_support_messages,
              [:ai_support_request_id, :created_at]

    add_index :ai_support_messages,
              [:user_id, :created_at]

    add_index :ai_support_messages,
              [:ai_support_request_id, :read_at]
  end
end