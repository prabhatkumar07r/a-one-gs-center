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

    normalized_phone =
      normalize_phone(phone)

    raise "Invalid student WhatsApp number." if normalized_phone.blank?

    # ---------------------------------------------------------
    # TEMPLATE PARAMETERS
    #
    # payment_success:
    # {{1}} = Student name
    # {{2}} = Course name
    # {{3}} = Payment ID
    # {{4}} = Amount
    # ---------------------------------------------------------

    parameters = [
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

    payload = {
      messaging_product: "whatsapp",

      to: normalized_phone,

      type: "template",

      template: {
        name: "payment_success",

        language: {
          code: "en"
        },

        components: [
          {
            type: "body",
            parameters: parameters
          }
        ]
      }
    }

    # ---------------------------------------------------------
    # SEND TO META
    # ---------------------------------------------------------

    response =
      send_meta_request(
        phone_number_id,
        access_token,
        payload
      )

    # ---------------------------------------------------------
    # SAVE TO WHATSAPP INBOX
    # ---------------------------------------------------------

    save_outgoing_message!(
      response: response,
      phone: normalized_phone,
      body: payment_success_body,
      message_type: "template"
    )

    response
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

    normalized_phone =
      normalize_phone(phone)

    raise "Invalid student WhatsApp number." if normalized_phone.blank?

    # ---------------------------------------------------------
    # TEMPLATE PARAMETERS
    # ---------------------------------------------------------

    parameters = [
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

    payload = {
      messaging_product: "whatsapp",

      to: normalized_phone,

      type: "template",

      template: {
        name: "payment_reminder",

        language: {
          code: "en"
        },

        components: [
          {
            type: "body",
            parameters: parameters
          }
        ]
      }
    }

    # ---------------------------------------------------------
    # SEND TO META
    # ---------------------------------------------------------

    response =
      send_meta_request(
        phone_number_id,
        access_token,
        payload
      )

    # ---------------------------------------------------------
    # SAVE TO WHATSAPP INBOX
    # ---------------------------------------------------------

    save_outgoing_message!(
      response: response,
      phone: normalized_phone,
      body: payment_reminder_body,
      message_type: "template"
    )

    response
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
  # 7061423558
  #       ↓
  # 917061423558
  #
  # 917061423558
  #       ↓
  # 917061423558
  # =========================================================

  def normalize_phone(phone)
    digits =
      phone.to_s.gsub(/\D/, "")

    return "" if digits.blank?

    # Already Indian country code
    if digits.start_with?("91") && digits.length == 12
      return digits
    end

    # Indian 10 digit mobile number
    if digits.length == 10
      return "91#{digits}"
    end

    # Keep other international numbers as-is
    digits
  end

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

    uri =
      URI.parse(url)

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

    # =======================================================
    # META ERROR
    # =======================================================

    unless response.is_a?(Net::HTTPSuccess)

      raise(
        "Meta WhatsApp API error " \
        "#{response.code}: #{response.body}"
      )
    end

    # =======================================================
    # PARSE RESPONSE
    # =======================================================

    JSON.parse(response.body)

  rescue JSON::ParserError => e

    Rails.logger.error(
      "[META WHATSAPP JSON PARSE ERROR] " \
      "#{e.class}: #{e.message} " \
      "BODY=#{response&.body}"
    )

    raise(
      "Invalid response received from Meta WhatsApp API."
    )
  end

  # =========================================================
  # SAVE OUTGOING WHATSAPP MESSAGE
  # =========================================================

  def save_outgoing_message!(
    response:,
    phone:,
    body:,
    message_type:
  )
    # -------------------------------------------------------
    # GET META MESSAGE ID
    # -------------------------------------------------------

    whatsapp_message_id =
      response
        .dig("messages", 0, "id")
        .to_s
        .strip

    if whatsapp_message_id.blank?

      Rails.logger.error(
        "[META WHATSAPP INBOX] " \
        "Meta response did not contain message ID. " \
        "RESPONSE=#{response.inspect}"
      )

      raise(
        "WhatsApp message was sent but Meta did not return a message ID."
      )
    end

    # -------------------------------------------------------
    # PREVENT DUPLICATE LOCAL MESSAGE
    # -------------------------------------------------------

    existing =
      WhatsappMessage.find_by(
        whatsapp_message_id: whatsapp_message_id
      )

    if existing
      Rails.logger.info(
        "[META WHATSAPP INBOX] " \
        "Message already exists. " \
        "id=#{existing.id} " \
        "wamid=#{whatsapp_message_id}"
      )

      return existing
    end

    # -------------------------------------------------------
    # CREATE OUTGOING MESSAGE
    # -------------------------------------------------------

    message =
      WhatsappMessage.create!(
        phone_number: phone,

        direction: "outgoing",

        body: body,

        message_type: message_type,

        status: "sent",

        whatsapp_message_id: whatsapp_message_id,

        sender_name: @student.name.to_s,

        status_updated_at: Time.current,

        whatsapp_timestamp: Time.current
      )

    Rails.logger.info(
      "[META WHATSAPP INBOX] " \
      "OUTGOING MESSAGE SAVED " \
      "id=#{message.id} " \
      "phone=#{phone} " \
      "wamid=#{whatsapp_message_id} " \
      "status=#{message.status}"
    )

    message

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "[META WHATSAPP INBOX] " \
      "FAILED TO SAVE MESSAGE " \
      "#{e.class}: #{e.message}"
    )

    raise
  end

  # =========================================================
  # INBOX BODY
  #
  # This is what the admin sees in the WhatsApp conversation.
  # =========================================================

  def payment_reminder_body
    [
      "Payment Reminder",
      "",
      "Hello #{@student.name},",
      "",
      "Your payment of ₹#{@payment.amount} " \
      "for #{@course.Course_name} is pending.",
      "",
      "Please complete your payment to continue your course."
    ].join("\n")
  end

  # =========================================================
  # PAYMENT SUCCESS BODY
  # =========================================================

  def payment_success_body
    [
      "Payment Successful",
      "",
      "Hello #{@student.name},",
      "",
      "Your payment of ₹#{@payment.amount} " \
      "for #{@course.Course_name} has been received successfully.",
      "",
      "Payment ID: #{@payment.id}"
    ].join("\n")
  end
end