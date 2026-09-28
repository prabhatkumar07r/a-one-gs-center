class CreateWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :user, null: true, foreign_key: true
      t.string :phone_number, null: false
      t.string :sender_name
      t.string :whatsapp_message_id, null: false
      t.string :message_type, null: false
      t.text :body
      t.string :direction, null: false, default: "incoming"
      t.datetime :whatsapp_timestamp
      t.datetime :read_at
      t.jsonb :metadata, null: false, default: {}
      t.jsonb :raw_payload, null: false, default: {}
      t.timestamps
    end

    add_index :whatsapp_messages,
              :whatsapp_message_id,
              unique: true

    add_index :whatsapp_messages,
              :phone_number

    add_index :whatsapp_messages,
              :direction

    add_index :whatsapp_messages,
              :read_at

    add_index :whatsapp_messages,
              :created_at
  end
end