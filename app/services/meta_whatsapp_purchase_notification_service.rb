
require "net/http"
require "json"
require "uri"

class MetaWhatsappPurchaseNotificationService
  GRAPH_API_VERSION = "v25.0"

  TEMPLATE_NAME = "purchase_success"
  TEMPLATE_LANGUAGE = "en"

  def initialize(purchase)
    @purchase = purchase
    @user = purchase.user

    @product =
      case purchase
      when EbookPurchase
        purchase.ebook
      when TestSeriesPurchase
        purchase.test_series
      else
        raise ArgumentError, "Unsupported purchase type"
      end
  end

  def send_success_message
    return false if @user.mobile.blank?

    token = ENV["META_WHATSAPP_ACCESS_TOKEN"]
    phone_number_id = ENV["META_WHATSAPP_PHONE_NUMBER_ID"]

    raise "WhatsApp access token missing" if token.blank?
    raise "WhatsApp phone number ID missing" if phone_number_id.blank?

    phone = normalize_phone(@user.mobile)

    payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
      type: "template",
      template: {
        name: TEMPLATE_NAME,
        language: { code: TEMPLATE_LANGUAGE },
        components: [
          {
            type: "body",
            parameters: [
              {
                type: "text",
                text: (@user.name.presence || "Student").to_s
              },
              {
                type: "text",
                text: @product.title.to_s
              },
              {
                type: "text",
                text: (
                  @purchase.razorpay_payment_id.presence ||
                  @purchase.razorpay_order_id.presence ||
                  "Purchase-#{@purchase.id}"
                ).to_s
              },
              {
                type: "text",
                text: format(
                  "%.2f",
                  @purchase.payable_amount.to_d
                )
              }
            ]
          }
        ]
      }
    }

    uri = URI(
      "https://graph.facebook.com/#{GRAPH_API_VERSION}/" \
      "#{phone_number_id}/messages"
    )

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
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

    result = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess) &&
           result.dig("messages", 0, "id").present?
      Rails.logger.error(
        "Purchase WhatsApp failed: " \
        "purchase_type=#{@purchase.class.name} " \
        "purchase_id=#{@purchase.id} " \
        "http_status=#{response.code} " \
        "response=#{response.body}"
      )

      raise "WhatsApp purchase notification failed"
    end

    Rails.logger.info(
      "Purchase WhatsApp accepted: " \
      "purchase_type=#{@purchase.class.name} " \
      "purchase_id=#{@purchase.id}"
    )

    true
  end

  private

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, "")

    # Indian mobile number without country code
    digits = "91#{digits}" if digits.length == 10

    unless digits.match?(/\A[1-9]\d{7,14}\z/)
      raise ArgumentError, "Invalid WhatsApp mobile number"
    end

    digits
  end
end
