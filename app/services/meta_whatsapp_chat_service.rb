require "net/http"
require "uri"
require "json"

class MetaWhatsappChatService
  class Error < StandardError
  end

  GRAPH_API_VERSION = "v25.0"

  META_WHATSAPP_URL =
    "https://graph.facebook.com/" \
    "#{GRAPH_API_VERSION}/" \
    "%{phone_number_id}/messages"

  def self.send_text(to:, body:)
    new.send_text(to: to, body: body)
  end

  def send_text(to:, body:)
    phone_number_id =
      ENV.fetch("META_WHATSAPP_PHONE_NUMBER_ID")

    access_token =
      ENV.fetch("META_WHATSAPP_ACCESS_TOKEN")

    normalized_phone =
      normalize_phone(to)

    message_body =
      body.to_s.strip

    raise Error, "Recipient phone number is missing" if normalized_phone.blank?
    raise Error, "Message body is blank" if message_body.blank?

    uri =
      URI(
        format(
          META_WHATSAPP_URL,
          phone_number_id: phone_number_id
        )
      )

    request =
      Net::HTTP::Post.new(uri)

    request["Authorization"] =
      "Bearer #{access_token}"

    request["Content-Type"] =
      "application/json"

    request.body =
      {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: normalized_phone,
        type: "text",
        text: {
          preview_url: false,
          body: message_body
        }
      }.to_json

    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30
      ) do |http|
        http.request(request)
      end

    response_body =
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        {
          "raw_response" => response.body.to_s
        }
      end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error,
            "Meta WhatsApp API failed " \
            "HTTP=#{response.code} " \
            "Response=#{response_body.to_json}"
    end

    response_body
  rescue KeyError => e
    raise Error,
          "#{e.key} is missing"
  rescue SocketError,
         Net::OpenTimeout,
         Net::ReadTimeout => e
    raise Error,
          "Unable to connect to Meta WhatsApp API: #{e.message}"
  end

  private

  def normalize_phone(phone)
    phone.to_s.gsub(/\D/, "")
  end
end