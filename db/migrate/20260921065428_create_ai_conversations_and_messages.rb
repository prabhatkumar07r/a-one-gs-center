class CreateAiConversationsAndMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, default: "New AI Chat"

      t.timestamps
    end

    add_index :ai_conversations, [:user_id, :updated_at]

    create_table :ai_messages do |t|
      t.references :ai_conversation,
                   null: false,
                   foreign_key: { to_table: :ai_conversations }

      t.string :role, null: false
      t.text :content, null: false
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens

      t.timestamps
    end

    add_index :ai_messages, [:ai_conversation_id, :created_at]
  end
end