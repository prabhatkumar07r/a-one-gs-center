class WhatsappWebhooksController < ActionController::API
  

  def verify
    mode = params["hub.mode"].to_s
    token = params["hub.verify_token"].to_s
    challenge = params["hub.challenge"].to_s
    verify_token = ENV["META_WHATSAPP_VERIFY_TOKEN"].to_s

    if mode == "subscribe" &&
       verify_token.present? &&
       token.present? &&
       secure_compare(token, verify_token)
      render plain: challenge, status: :ok
    else
      render plain: "Forbidden", status: :forbidden
    end
  end

  def receive
    raw_body = request.raw_post

    unless valid_signature?(raw_body)
      Rails.logger.warn("[META WHATSAPP WEBHOOK] Invalid signature")
      head :unauthorized
      return
    end

    data = JSON.parse(raw_body)

    process_webhook(data)

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error(
      "[META WHATSAPP WEBHOOK JSON ERROR] #{e.message}"
    )
    head :bad_request
  rescue StandardError => e
    Rails.logger.error(
      "[META WHATSAPP WEBHOOK ERROR] #{e.class}: #{e.message}"
    )
    Rails.logger.error(
      Array(e.backtrace).first(10).join("\n")
    )
    head :ok
  end

  private

  def valid_signature?(raw_body)
    app_secret = ENV["META_APP_SECRET"].to_s
    received_signature =
      request.headers["X-Hub-Signature-256"].to_s

    return false if app_secret.blank?
    return false if received_signature.blank?

    expected_signature =
      "sha256=" +
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("SHA256"),
        app_secret,
        raw_body
      )

    secure_compare(
      received_signature,
      expected_signature
    )
  end

  def secure_compare(first, second)
    return false if first.blank? || second.blank?
    return false unless first.bytesize == second.bytesize

    ActiveSupport::SecurityUtils.secure_compare(
      first,
      second
    )
  end

  def process_webhook(data)
    return unless data["object"] == "whatsapp_business_account"

    data.fetch("entry", []).each do |entry|
      entry.fetch("changes", []).each do |change|
        next unless change["field"].to_s == "messages"

        value = change["value"] || {}

        process_statuses(value)
        process_messages(value)
      end
    end
  end

  def process_statuses(value)
    value.fetch("statuses", []).each do |status|
      message_id = status["id"].to_s
      status_value = status["status"].to_s
      recipient = status["recipient_id"].to_s
      timestamp = status["timestamp"].to_s

      Rails.logger.info(
        "[META WHATSAPP STATUS] " \
        "status=#{status_value} " \
        "message_id=#{message_id} " \
        "recipient=#{recipient} " \
        "timestamp=#{timestamp}"
      )

      if status_value == "failed"
        Rails.logger.error(
          "[META WHATSAPP FAILED] #{status["errors"].inspect}"
        )
      end
    end
  end

  def process_messages(value)
    messages = Array(value["messages"])
    contacts = Array(value["contacts"])

    messages.each do |message|
      process_message(
        message,
        value,
        contacts
      )
    end
  end

  def process_message(message, value, contacts)
    whatsapp_message_id = message["id"].to_s
    phone_number = message["from"].to_s
    message_type = message["type"].to_s

    return if whatsapp_message_id.blank?
    return if phone_number.blank?

    if WhatsappMessage.exists?(
      whatsapp_message_id: whatsapp_message_id
    )
      Rails.logger.info(
        "[META WHATSAPP] Duplicate message skipped #{whatsapp_message_id}"
      )
      return
    end

    contact =
      contacts.find do |item|
        item["wa_id"].to_s == phone_number
      end

    sender_name =
      contact&.dig("profile", "name").to_s.presence

    user =
      find_user_by_phone(phone_number)

    timestamp =
      parse_whatsapp_timestamp(
        message["timestamp"]
      )

    whatsapp_message =
      WhatsappMessage.create!(
        user: user,
        phone_number: phone_number,
        sender_name: sender_name,
        whatsapp_message_id: whatsapp_message_id,
        message_type: message_type,
        body: extract_message_body(message),
        direction: "incoming",
        whatsapp_timestamp: timestamp,
        metadata: {
          phone_number_id: value.dig(
            "metadata",
            "phone_number_id"
          ),
          display_phone_number: value.dig(
            "metadata",
            "display_phone_number"
          ),
          message_type: message_type,
          context: message["context"]
        }.compact,
        raw_payload: message
      )

    Rails.logger.info(
      "[META WHATSAPP INCOMING SAVED] " \
      "id=#{whatsapp_message.id} " \
      "message_id=#{whatsapp_message_id} " \
      "phone=#{phone_number} " \
      "user_id=#{user&.id || 'unmatched'}"
    )
  end

  def extract_message_body(message)
    case message["type"].to_s
    when "text"
      message.dig("text", "body").to_s
    when "button"
      message.dig("button", "text").to_s
    when "interactive"
      message.dig(
        "interactive",
        "button_reply",
        "title"
      ).to_s.presence ||
        message.dig(
          "interactive",
          "list_reply",
          "title"
        ).to_s.presence ||
        "[Interactive response]"
    when "image"
      message.dig(
        "image",
        "caption"
      ).to_s.presence || "[Image message]"
    when "video"
      message.dig(
        "video",
        "caption"
      ).to_s.presence || "[Video message]"
    when "document"
      filename =
        message.dig(
          "document",
          "filename"
        ).to_s

      if filename.present?
        "[Document] #{filename}"
      else
        "[Document message]"
      end
    when "audio"
      "[Audio message]"
    when "sticker"
      "[Sticker message]"
    when "location"
      location = message["location"] || {}
      name = location["name"].to_s
      address = location["address"].to_s

      if name.present?
        "[Location] #{name}"
      elsif address.present?
        "[Location] #{address}"
      else
        "[Location message]"
      end
    when "contacts"
      "[Contact message]"
    when "reaction"
      emoji =
        message.dig(
          "reaction",
          "emoji"
        ).to_s

      if emoji.present?
        "[Reaction] #{emoji}"
      else
        "[Reaction]"
      end
    else
      "[#{message["type"].presence || "Unknown"} message]"
    end
  end

  def parse_whatsapp_timestamp(timestamp)
    return nil if timestamp.blank?

    Time.at(timestamp.to_i).utc
  rescue StandardError
    nil
  end

  def find_user_by_phone(phone_number)
    normalized =
      phone_number.to_s.gsub(/\D/, "")

    return nil if normalized.blank?

    columns =
      %w[phone mobile].select do |column|
        User.column_names.include?(column)
      end

    return nil if columns.empty?

    conditions = []
    values = []

    columns.each do |column|
      conditions << <<~SQL.squish
        regexp_replace(
          COALESCE(#{column}::text, ''),
          '[^0-9]',
          '',
          'g'
        ) = ?
      SQL

      values << normalized

      if normalized.length >= 10
        conditions << <<~SQL.squish
          RIGHT(
            regexp_replace(
              COALESCE(#{column}::text, ''),
              '[^0-9]',
              '',
              'g'
            ),
            10
          ) = ?
        SQL

        values << normalized.last(10)
      end
    end

    User
      .where(
        conditions.join(" OR "),
        *values
      )
      .first
  rescue StandardError => e
    Rails.logger.error(
      "[META WHATSAPP USER LOOKUP ERROR] " \
      "#{e.class}: #{e.message}"
    )

    nil
  end
end