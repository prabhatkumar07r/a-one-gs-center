class AddSuccessNotificationTimestampsToPurchases < ActiveRecord::Migration[8.1]
  def change
    add_column :ebook_purchases, :success_email_sent_at, :datetime
    add_column :ebook_purchases, :success_whatsapp_sent_at, :datetime

    add_column :test_series_purchases, :success_email_sent_at, :datetime
    add_column :test_series_purchases, :success_whatsapp_sent_at, :datetime
  end
end