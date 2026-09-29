class AddInboxLatestMessageIndexToWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    add_index :whatsapp_messages,
              [:phone_number, :created_at, :id],
              name: "index_whatsapp_messages_on_phone_created_id"
  end
end