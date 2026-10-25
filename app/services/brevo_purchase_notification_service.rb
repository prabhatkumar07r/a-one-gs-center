
require "net/http"
require "json"
require "uri"
require "erb"

class BrevoPurchaseNotificationService
  API_URL = "https://api.brevo.com/v3/smtp/email"

  def initialize(purchase)
    @purchase = purchase
    @user = purchase.user
    @product =
      if purchase.is_a?(EbookPurchase)
        purchase.ebook
      elsif purchase.is_a?(TestSeriesPurchase)
        purchase.test_series
      else
        raise ArgumentError, "Unsupported purchase type"
      end
  end

  def send_success_email
    return false if @user.email.blank?

    api_key = ENV["BREVO_API_KEY"]
    raise "BREVO_API_KEY is missing" if api_key.blank?

    sender_email =
      ENV.fetch("BREVO_SENDER_EMAIL", "supportaonegscenter@gmail.com")

    sender_name =
      ENV.fetch("BREVO_SENDER_NAME", "A One GS Center")

    escape = ->(value) { ERB::Util.html_escape(value.to_s) }

    student_name = escape.call(@user.name.presence || "Student")
    product_name = escape.call(@product.title)
    amount = format("%.2f", @purchase.payable_amount.to_d)
    reference = escape.call(
      @purchase.razorpay_payment_id.presence ||
      @purchase.razorpay_order_id.presence ||
      "Purchase ##{@purchase.id}"
    )

    html = <<~HTML
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;color:#222">
        <h2 style="color:#8009e2">Payment Successful!</h2>
        <p>Hello #{student_name},</p>
        <p>Your payment has been received successfully.</p>
        <p><strong>Product:</strong> #{product_name}</p>
        <p><strong>Amount:</strong> ₹#{amount}</p>
        <p><strong>Payment reference:</strong> #{reference}</p>
        <p>You can sign in to your account to access your purchase.</p>
        <p><a href="https://aonegscenter.com"
              style="background:#8009e2;color:white;padding:12px 20px;text-decoration:none;border-radius:6px">
          Visit A One GS Center
        </a></p>
        <p>Regards,<br>A One GS Center</p>
      </div>
    HTML

    payload = {
      sender: {
        name: sender_name,
        email: sender_email
      },
      to: [
        {
          email: @user.email,
          name: @user.name.presence || "Student"
        }
      ],
      subject: "Payment Successful - #{@product.title}",
      htmlContent: html
    }

    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["api-key"] = api_key
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 20
    ) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Brevo email failed: HTTP #{response.code}"
    end

    Rails.logger.info(
      "PURCHASE SUCCESS EMAIL SENT: " \
      "type=#{@purchase.class.name}, purchase=#{@purchase.id}"
    )

    true
  end
end
