class AddNotificationTrackingToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :success_email_sent_at, :datetime
    add_column :payments, :success_whatsapp_sent_at, :datetime
  end
end
