require "net/http"
require "uri"
require "json"

class MetaWhatsappNotificationService

  GRAPH_API_VERSION = "v25.0"

  META_WHATSAPP_URL =
    "https://graph.facebook.com/" \
    "#{GRAPH_API_VERSION}/" \
    "%{phone_number_id}/messages"

  # =========================================================
  # PAYMENT SUCCESS
  # =========================================================

  def self.send_payment_success(payment)
    new(payment).send_payment_success
  end

  # =========================================================
  # PAYMENT REMINDER
  # =========================================================

  def self.send_payment_reminder(payment)
    new(payment).send_payment_reminder
  end

  # =========================================================
  # INITIALIZE
  # =========================================================

  def initialize(payment)
    @payment = payment
    @enrollment = payment.enrollment
    @student = @enrollment.user
    @course = @enrollment.course
  end

  # =========================================================
  # SEND PAYMENT SUCCESS WHATSAPP
  # =========================================================

  def send_payment_success
    phone = student_phone

    raise "Student WhatsApp number is missing." if phone.blank?

    phone_number_id =
      ENV.fetch("META_WHATSAPP_PHONE_NUMBER_ID")

    access_token =
      ENV.fetch("META_WHATSAPP_ACCESS_TOKEN")

    payload = {
      messaging_product: "whatsapp",

      to: normalize_phone(phone),

      type: "template",

      template: {
        name: "payment_success",

        language: {
          code: "en"
        },

        components: [
          {
            type: "body",

            parameters: [
              {
                type: "text",
                text: @student.name.to_s
              },
              {
                type: "text",
                text: @course.Course_name.to_s
              },
              {
                type: "text",
                text: @payment.id.to_s
              },
              {
                type: "text",
                text: @payment.amount.to_s
              }
            ]
          }
        ]
      }
    }

    send_meta_request(
      phone_number_id,
      access_token,
      payload
    )
  end

  # =========================================================
  # SEND PAYMENT REMINDER WHATSAPP
  #
  # payment_reminder template:
  #
  # {{1}} = Student name
  # {{2}} = Pending amount
  # {{3}} = Course name
  # =========================================================

  def send_payment_reminder
    phone = student_phone

    raise "Student WhatsApp number is missing." if phone.blank?

    phone_number_id =
      ENV.fetch("META_WHATSAPP_PHONE_NUMBER_ID")

    access_token =
      ENV.fetch("META_WHATSAPP_ACCESS_TOKEN")

    payload = {
      messaging_product: "whatsapp",

      to: normalize_phone(phone),

      type: "template",

      template: {
        name: "payment_reminder",

        language: {
          code: "en"
        },

        components: [
          {
            type: "body",

            parameters: [
              {
                type: "text",
                text: @student.name.to_s
              },
              {
                type: "text",
                text: @payment.amount.to_s
              },
              {
                type: "text",
                text: @course.Course_name.to_s
              }
            ]
          }
        ]
      }
    }

    send_meta_request(
      phone_number_id,
      access_token,
      payload
    )
  end

  private

  # =========================================================
  # STUDENT PHONE
  # =========================================================

  def student_phone
    if @student.respond_to?(:phone)
      @student.phone.to_s.strip

    elsif @student.respond_to?(:mobile)
      @student.mobile.to_s.strip

    else
      ""
    end
  end

  # =========================================================
  # PHONE NORMALIZATION
  #
  # 7061423558 -> 917061423558
  # =========================================================

  def normalize_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")

    return digits if digits.start_with?("91") && digits.length == 12

    return "91#{digits}" if digits.length == 10

    digits
  end

  # =========================================================
  # META REQUEST
  # =========================================================

# =========================================================
# META REQUEST
# =========================================================

def send_meta_request(
  phone_number_id,
  access_token,
  payload
)
  url =
    format(
      META_WHATSAPP_URL,
      phone_number_id: phone_number_id
    )

  uri = URI.parse(url)

  request =
    Net::HTTP::Post.new(uri)

  request["Authorization"] =
    "Bearer #{access_token}"

  request["Content-Type"] =
    "application/json"

  request.body =
    JSON.generate(payload)

  http =
    Net::HTTP.new(
      uri.host,
      uri.port
    )

  http.use_ssl = true

  response =
    http.request(request)

  # =======================================================
  # LOG META RESPONSE
  # =======================================================

  Rails.logger.info(
    "[META WHATSAPP RESPONSE] " \
    "HTTP=#{response.code} " \
    "BODY=#{response.body}"
  )

  unless response.is_a?(Net::HTTPSuccess)
    raise(
      "Meta WhatsApp API error " \
      "#{response.code}: #{response.body}"
    )
  end

  JSON.parse(response.body)

rescue JSON::ParserError
  Rails.logger.error(
    "[META WHATSAPP JSON PARSE ERROR] " \
    "#{response.body}"
  )

  {
    "success" => true,
    "raw_response" => response.body
  }
end
end