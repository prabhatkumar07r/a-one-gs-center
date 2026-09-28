class AddStatusToWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_messages, :status, :string, null: false, default: "sent"
    add_column :whatsapp_messages, :status_updated_at, :datetime

    add_index :whatsapp_messages, :status
  end
end