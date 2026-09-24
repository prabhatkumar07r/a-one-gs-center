class CreateAiSupportRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_support_requests do |t|
      t.references :user,
                   null: false,
                   foreign_key: true

      t.references :ai_conversation,
                   null: false,
                   foreign_key: {
                     to_table: :ai_conversations
                   }

      t.string :category,
               null: false,
               default: "other"

      t.string :subject,
               null: false

      t.text :description,
              null: false

      t.text :ai_context

      t.string :status,
               null: false,
               default: "open"

      t.string :priority,
               null: false,
               default: "normal"

      t.text :admin_reply

      t.bigint :admin_user_id

      t.datetime :replied_at

      t.datetime :resolved_at

      t.timestamps
    end

    add_foreign_key :ai_support_requests,
                    :users,
                    column: :admin_user_id

    add_index :ai_support_requests,
              [:user_id, :status]

    add_index :ai_support_requests,
              [:status, :priority]

    add_index :ai_support_requests,
              [:ai_conversation_id, :created_at]
  end
end