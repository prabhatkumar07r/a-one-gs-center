class AddRazorpayQrFieldsToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :razorpay_qr_id, :string
    add_column :payments, :razorpay_qr_image_url, :string
  end
end
