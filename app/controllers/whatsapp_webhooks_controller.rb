class WhatsappWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  STATUS_RANK = {
    "sent" => 1,
    "delivered" => 2,
    "read" => 3,
    "failed" => 4
  }.freeze

  STATUS_CACHE_PREFIX = "whatsapp:message_status:"
  STATUS_CACHE_TTL = 10.minutes

  # =========================================================
  # META WEBHOOK VERIFY
  # =========================================================

  def verify
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    verify_token =
      ENV["META_WHATSAPP_VERIFY_TOKEN"].to_s

    valid =
      mode == "subscribe" &&
      verify_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(
        token.to_s,
        verify_token
      )

    if valid
      render plain: challenge, status: :ok
    else
      render plain: "Forbidden", status: :forbidden
    end
  end

  # =========================================================
  # META WEBHOOK RECEIVE
  # =========================================================

  def receive
    raw_body = request.raw_post

    unless valid_signature?(raw_body)
      Rails.logger.warn(
        "[META WHATSAPP WEBHOOK] Invalid signature"
      )

      return render(
        plain: "Forbidden",
        status: :forbidden
      )
    end

    payload = JSON.parse(raw_body)

    Rails.logger.info(
      "[META WHATSAPP WEBHOOK] " \
      "Received object=#{payload["object"]}"
    )

    process_payload(payload)

    render plain: "EVENT_RECEIVED", status: :ok

  rescue JSON::ParserError => e
    Rails.logger.error(
      "[META WHATSAPP WEBHOOK JSON ERROR] #{e.message}"
    )

    render plain: "Invalid JSON", status: :bad_request

  rescue StandardError => e
    Rails.logger.error(
      "[META WHATSAPP WEBHOOK ERROR] " \
      "#{e.class}: #{e.message}\n" \
      "#{e.backtrace&.first(10)&.join("\n")}"
    )

    # Return 200 so Meta does not continuously retry.
    render plain: "EVENT_RECEIVED", status: :ok
  end

  private

  # =========================================================
  # SIGNATURE
  # =========================================================

  def valid_signature?(raw_body)
    app_secret =
      ENV["META_APP_SECRET"].to_s

    return false if app_secret.blank?

    received_signature =
      request.headers["X-Hub-Signature-256"].to_s

    return false if received_signature.blank?

    expected_signature =
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("SHA256"),
        app_secret,
        raw_body
      )

    expected_header =
      "sha256=#{expected_signature}"

    ActiveSupport::SecurityUtils.secure_compare(
      received_signature,
      expected_header
    )
  end

  # =========================================================
  # PAYLOAD
  # =========================================================

  def process_payload(payload)
    Array(payload["entry"]).each do |entry|
      Array(entry["changes"]).each do |change|
        next unless change["field"] == "messages"

        value = change["value"] || {}

        # Outgoing delivery/read events
        process_statuses(value)

        # Incoming user messages
        process_messages(value)
      end
    end
  end

  # =========================================================
  # STATUS EVENTS
  #
  # sent
  # delivered
  # read
  # failed
  # =========================================================

  def process_statuses(value)
    Array(value["statuses"]).each do |status|
      message_id =
        status["id"].to_s.strip

      next if message_id.blank?

      normalized_status =
        normalize_status(status["status"])

      next if normalized_status.blank?

      status_time =
        parse_meta_timestamp(status["timestamp"]) ||
        Time.current

      Rails.logger.info(
        "[META WHATSAPP STATUS] " \
        "status=#{normalized_status} " \
        "message_id=#{message_id} " \
        "recipient=#{status["recipient_id"]} " \
        "timestamp=#{status["timestamp"]}"
      )

      message =
        WhatsappMessage.find_by(
          whatsapp_message_id: message_id
        )

      if message
        Rails.logger.info(
          "[META WHATSAPP STATUS] " \
          "FOUND DB MESSAGE id=#{message.id} " \
          "current_status=#{message.status}"
        )

        apply_status(
          message,
          normalized_status,
          status_time
        )
      else
        # ===================================================
        # WEBHOOK CAN ARRIVE BEFORE SEND ACTION SAVES
        # THE REAL META MESSAGE ID.
        # ===================================================

        cache_status(
          message_id,
          normalized_status,
          status_time
        )

        Rails.logger.warn(
          "[META WHATSAPP STATUS] " \
          "MESSAGE NOT FOUND; CACHED " \
          "message_id=#{message_id} " \
          "status=#{normalized_status}"
        )
      end
    end
  end

  # =========================================================
  # APPLY STATUS
  # =========================================================

  def apply_status(
    message,
    new_status,
    status_time
  )
    current_status =
      message.status.to_s.presence || "sent"

    current_rank =
      STATUS_RANK[current_status].to_i

    new_rank =
      STATUS_RANK[new_status].to_i

    # -----------------------------------------------
    # READ IS FINAL FOR NORMAL DELIVERY FLOW.
    # Never downgrade read -> delivered/sent.
    # -----------------------------------------------

    if current_status == "read" &&
       new_status != "read"
      Rails.logger.info(
        "[META WHATSAPP STATUS] " \
        "Ignored downgrade " \
        "#{message.id}: read -> #{new_status}"
      )

      return
    end

    # -----------------------------------------------
    # FAILED should not overwrite READ.
    # -----------------------------------------------

    if current_status == "read" &&
       new_status == "failed"
      return
    end

    # -----------------------------------------------
    # If failed is already stored, allow read to
    # recover the message, otherwise don't downgrade.
    # -----------------------------------------------

    if current_status == "failed" &&
       new_status != "read" &&
       new_status != "failed"
      Rails.logger.info(
        "[META WHATSAPP STATUS] " \
        "Ignored downgrade " \
        "#{message.id}: failed -> #{new_status}"
      )

      return
    end

    # -----------------------------------------------
    # Normal monotonic progression:
    #
    # sent -> delivered -> read
    # -----------------------------------------------

    if new_status != "failed" &&
       current_status != "failed" &&
       new_rank < current_rank

      Rails.logger.info(
        "[META WHATSAPP STATUS] " \
        "Ignored regression " \
        "#{message.id}: " \
        "#{current_status} -> #{new_status}"
      )

      return
    end

    existing_time =
      message.status_updated_at

    final_time =
      [
        existing_time,
        status_time
      ].compact.max

    message.update_columns(
      status: new_status,
      status_updated_at: final_time,
      updated_at: Time.current
    )

    Rails.logger.info(
      "[META WHATSAPP STATUS] " \
      "DB UPDATED id=#{message.id} " \
      "#{current_status} -> #{new_status}"
    )
  end

  # =========================================================
  # CACHE STATUS
  # =========================================================

  def cache_status(
    message_id,
    status,
    timestamp
  )
    key =
      whatsapp_status_cache_key(message_id)

    existing =
      Rails.cache.read(key)

    existing_status =
      existing&.dig("status").to_s

    existing_time =
      begin
        Time.iso8601(
          existing&.dig("timestamp").to_s
        )
      rescue ArgumentError,
             TypeError
        nil
      end

    # Keep the strongest status.
    final_status =
      stronger_status(
        existing_status,
        status
      )

    final_time =
      [
        existing_time,
        timestamp
      ].compact.max

    Rails.cache.write(
      key,
      {
        "status" => final_status,
        "timestamp" =>
          final_time&.iso8601(6)
      },
      expires_in: STATUS_CACHE_TTL
    )
  end

  # =========================================================
  # STRONGER STATUS
  # =========================================================

  def stronger_status(first, second)
    return second if first.blank?
    return first if second.blank?

    first_rank =
      STATUS_RANK[first].to_i

    second_rank =
      STATUS_RANK[second].to_i

    second_rank >= first_rank ?
      second :
      first
  end

  # =========================================================
  # INCOMING MESSAGES
  # =========================================================

  def process_messages(value)
    Array(value["messages"]).each do |message_data|
      save_incoming_message(
        value,
        message_data
      )
    end
  end

  # =========================================================
  # SAVE INCOMING
  # =========================================================

  def save_incoming_message(
    value,
    message_data
  )
    whatsapp_message_id =
      message_data["id"].to_s.strip

    return if whatsapp_message_id.blank?

    existing =
      WhatsappMessage.find_by(
        whatsapp_message_id: whatsapp_message_id
      )

    return if existing

    phone =
      message_data["from"].to_s.strip

    return if phone.blank?

    message_type =
      message_data["type"].to_s.presence ||
      "unknown"

    body =
      extract_message_body(message_data)

    sender_name =
      value
        .dig(
          "contacts",
          0,
          "profile",
          "name"
        )
        .to_s
        .presence ||
      phone

    user =
      find_user_by_phone(phone)

    timestamp =
      parse_meta_timestamp(
        message_data["timestamp"]
      ) || Time.current

    WhatsappMessage.create!(
      user: user,
      phone_number: phone,
      sender_name: sender_name,
      whatsapp_message_id: whatsapp_message_id,
      message_type: message_type,
      body: body,
      direction: "incoming",
      status: "sent",
      status_updated_at: timestamp,
      whatsapp_timestamp: timestamp,
      metadata: {
        context: message_data["context"]
      },
      raw_payload: message_data
    )

    Rails.logger.info(
      "[META WHATSAPP INCOMING] " \
      "#{phone}: #{body}"
    )

  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info(
      "[META WHATSAPP INCOMING] " \
      "Duplicate ignored: #{whatsapp_message_id}"
    )
  end

  # =========================================================
  # EXTRACT BODY
  # =========================================================

  def extract_message_body(message)
    type =
      message["type"].to_s

    case type

    when "text"
      message
        .dig("text", "body")
        .to_s

    when "button"
      message
        .dig("button", "text")
        .to_s

    when "interactive"
      interactive =
        message["interactive"] || {}

      if interactive["type"] == "button_reply"
        interactive
          .dig("button_reply", "title")
          .to_s

      elsif interactive["type"] == "list_reply"
        interactive
          .dig("list_reply", "title")
          .to_s

      else
        "[Interactive message]"
      end

    when "image"
      caption =
        message
          .dig("image", "caption")
          .to_s

      caption.present? ?
        "[Image] #{caption}" :
        "[Image]"

    when "video"
      caption =
        message
          .dig("video", "caption")
          .to_s

      caption.present? ?
        "[Video] #{caption}" :
        "[Video]"

    when "document"
      filename =
        message
          .dig("document", "filename")
          .to_s

      filename.present? ?
        "[Document] #{filename}" :
        "[Document]"

    when "audio"
      "[Audio]"

    when "sticker"
      "[Sticker]"

    when "location"
      latitude =
        message.dig(
          "location",
          "latitude"
        )

      longitude =
        message.dig(
          "location",
          "longitude"
        )

      "[Location] #{latitude}, #{longitude}"

    when "contacts"
      "[Contact]"

    when "reaction"
      emoji =
        message
          .dig("reaction", "emoji")
          .to_s

      "[Reaction] #{emoji}"

    else
      "[#{type.titleize}]"
    end
  end

  # =========================================================
  # USER LOOKUP
  # =========================================================

  def find_user_by_phone(phone)
    normalized =
      phone
        .to_s
        .gsub(/\D/, "")

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

  # =========================================================
  # STATUS NORMALIZATION
  # =========================================================

  def normalize_status(status)
    case status.to_s.downcase
    when "sent"
      "sent"
    when "delivered"
      "delivered"
    when "read"
      "read"
    when "failed"
      "failed"
    else
      nil
    end
  end

  # =========================================================
  # META TIMESTAMP
  # =========================================================

  def parse_meta_timestamp(timestamp)
    return nil if timestamp.blank?

    Time.at(
      timestamp.to_i
    )
  rescue ArgumentError,
         TypeError
    nil
  end

  # =========================================================
  # CACHE KEY
  # =========================================================

  def whatsapp_status_cache_key(message_id)
    "#{STATUS_CACHE_PREFIX}#{message_id}"
  end
end