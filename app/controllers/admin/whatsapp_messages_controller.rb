class Admin::WhatsappMessagesController < ApplicationController
  before_action :require_admin

  before_action :set_phone,
                only: %i[
                  conversation
                  messages
                  send_message
                ]

  layout "admin"

  PER_PAGE = 100

  def index
    load_inbox

    respond_to do |format|
      format.html
      format.json do
        no_cache!

        render json: {
          conversations: @conversations.map do |conversation|
            serialize_conversation(
              conversation,
              @unread_counts[conversation.phone_number].to_i
            )
          end,
          unread_count: @unread_count,
          server_time: Time.current.iso8601(6)
        }
      end
    end
  end

  def conversation
    load_inbox

    @messages =
      WhatsappMessage
        .where(phone_number: @phone)
        .order(id: :asc)

    WhatsappMessage
      .where(
        phone_number: @phone,
        direction: "incoming",
        read_at: nil
      )
      .update_all(
        read_at: Time.current,
        updated_at: Time.current
      )

    @user =
      @messages
        .where.not(user_id: nil)
        .last
        &.user

    # The UI is in index.html.erb.
    render :index
  end

  # =========================================================
  # LIVE MESSAGE + STATUS POLLING
  # =========================================================

  def messages
    no_cache!

    after_id =
      params[:after_id].to_i

    status_after =
      parse_time(params[:status_after])

    new_messages = []

    if after_id.positive?
      new_messages =
        WhatsappMessage
          .where(phone_number: @phone)
          .where("id > ?", after_id)
          .order(id: :asc)
          .limit(PER_PAGE)
          .to_a
    else
      new_messages =
        WhatsappMessage
          .where(phone_number: @phone)
          .order(id: :desc)
          .limit(PER_PAGE)
          .to_a
          .reverse
    end

    # =======================================================
    # IMPORTANT:
    # Existing outgoing messages can change:
    #
    # sent -> delivered -> read
    #
    # Their DB id does NOT change.
    #
    # Therefore we separately fetch messages whose
    # status_updated_at changed after the browser cursor.
    # =======================================================

    status_messages = []

    if status_after
      status_messages =
        WhatsappMessage
          .where(phone_number: @phone)
          .where.not(status_updated_at: nil)
          .where("status_updated_at > ?", status_after)
          .order(status_updated_at: :asc, id: :asc)
          .limit(PER_PAGE)
          .to_a
    end

    combined =
      (new_messages + status_messages)
        .uniq(&:id)
        .sort_by(&:id)

    latest_id =
      [
        after_id,
        combined.map(&:id).compact.max,
        WhatsappMessage
          .where(phone_number: @phone)
          .maximum(:id)
      ].compact.max.to_i

    latest_status_time =
      combined
        .map(&:status_updated_at)
        .compact
        .max

    # If no status changed during this request, preserve
    # the browser's current cursor.
    latest_status_cursor =
      latest_status_time ||
      status_after ||
      Time.current

    render json: {
      phone: @phone,

      messages:
        combined.map do |message|
          serialize_message(message)
        end,

      latest_id: latest_id,

      status_cursor:
        latest_status_cursor.iso8601(6),

      server_time:
        Time.current.iso8601(6)
    }
  end

  # =========================================================
  # SEND WHATSAPP MESSAGE
  # =========================================================

  def send_message
    body =
      params[:body]
        .to_s
        .strip

    client_message_id =
      params[:client_message_id]
        .to_s
        .strip

    if body.blank?
      return render_send_error(
        "Message cannot be blank.",
        :unprocessable_entity
      )
    end

    local_message_id =
      "local-#{SecureRandom.uuid}"

    message = nil

    begin
      # =====================================================
      # CREATE LOCAL RECORD BEFORE CALLING META
      #
      # This prevents the UI from waiting for the webhook.
      # =====================================================

      message =
        WhatsappMessage.create!(
          user: find_user,

          phone_number:
            @phone,

          sender_name:
            "A One GS Center",

          whatsapp_message_id:
            local_message_id,

          message_type:
            "text",

          body:
            body,

          direction:
            "outgoing",

          status:
            "sent",

          status_updated_at:
            Time.current,

          whatsapp_timestamp:
            Time.current,

          metadata: {
            client_message_id:
              client_message_id.presence
          },

          raw_payload: {}
        )

      # =====================================================
      # CALL META
      # =====================================================

      meta_response =
        MetaWhatsappChatService.send_text(
          to: @phone,
          body: body
        )

      whatsapp_message_id =
        meta_response
          .dig(
            "messages",
            0,
            "id"
          )
          .to_s

      if whatsapp_message_id.blank?
        raise MetaWhatsappChatService::Error,
              "Meta did not return a WhatsApp message ID."
      end

      # =====================================================
      # UPDATE LOCAL RECORD WITH REAL META MESSAGE ID
      # =====================================================

      message.update!(
        whatsapp_message_id:
          whatsapp_message_id,

        metadata:
          (message.metadata || {}).merge(
            "client_message_id" =>
              client_message_id.presence,

            "api_response" =>
              meta_response
          ),

        raw_payload:
          meta_response,

        updated_at:
          Time.current
      )

      # =====================================================
      # IMPORTANT RACE-CONDITION FIX
      #
      # Sometimes Meta sends:
      #
      # sent / delivered / read
      #
      # before the database record gets the real Meta ID.
      #
      # The webhook stores that temporary status in Rails.cache.
      #
      # Read it now and apply it.
      # =====================================================

      cached_status =
        Rails.cache.read(
          whatsapp_status_cache_key(
            whatsapp_message_id
          )
        )

      if cached_status.present?
        apply_status_to_message(
          message,
          cached_status["status"],
          cached_status["timestamp"]
        )

        Rails.cache.delete(
          whatsapp_status_cache_key(
            whatsapp_message_id
          )
        )

        message.reload
      end

      if request.format.json?
        no_cache!

        return render json: {
          success: true,

          message:
            serialize_message(message).merge(
              client_message_id:
                client_message_id.presence
            )
        }, status: :created
      end

      redirect_to(
        admin_whatsapp_conversation_path(
          phone: @phone
        ),
        notice: "Message sent successfully."
      )

    rescue MetaWhatsappChatService::Error => e
      Rails.logger.error(
        "[ADMIN WHATSAPP SEND ERROR] " \
        "#{e.class}: #{e.message}"
      )

      # If local message exists, mark it failed.
      if message&.persisted?
        message.update(
          status: "failed",
          status_updated_at: Time.current
        )
      end

      render_send_error(
        e.message,
        :unprocessable_entity
      )

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "[ADMIN WHATSAPP DB ERROR] " \
        "#{e.class}: #{e.message}"
      )

      render_send_error(
        "Message could not be saved.",
        :unprocessable_entity
      )

    rescue StandardError => e
      Rails.logger.error(
        "[ADMIN WHATSAPP SEND ERROR] " \
        "#{e.class}: #{e.message}"
      )

      if message&.persisted?
        message.update(
          status: "failed",
          status_updated_at: Time.current
        )
      end

      render_send_error(
        "Unable to send WhatsApp message.",
        :internal_server_error
      )
    end
  end

  private

  # =========================================================
  # INBOX LOADER
  # =========================================================

  def load_inbox
    @conversations =
      WhatsappMessage
        .select(
          "DISTINCT ON (phone_number) whatsapp_messages.*"
        )
        .order(
          Arel.sql(
            "phone_number, created_at DESC, id DESC"
          )
        )
        .to_a

    @conversations =
      @conversations
        .sort_by do |conversation|
          conversation.created_at || Time.at(0)
        end
        .reverse

    phones =
      @conversations
        .map(&:phone_number)
        .compact
        .uniq

    if phones.any?
      @unread_counts =
        WhatsappMessage
          .incoming
          .unread
          .where(phone_number: phones)
          .group(:phone_number)
          .count
    else
      @unread_counts = {}
    end

    @unread_count =
      @unread_counts.values.sum

    @messages ||= []

    @user ||= nil
  end

  # =========================================================
  # SERIALIZE MESSAGE
  # =========================================================

  def serialize_message(message)
    {
      id:
        message.id,

      direction:
        message.direction,

      body:
        message.body,

      message_type:
        message.message_type,

      sender_name:
        message.sender_name,

      phone_number:
        message.phone_number,

      status:
        message.status,

      status_icon:
        message.status_icon,

      status_updated_at:
        message.status_updated_at&.iso8601(6),

      read_at:
        message.read_at&.iso8601(6),

      created_at:
        message.created_at&.iso8601(6),

      whatsapp_timestamp:
        message.whatsapp_timestamp&.iso8601(6),

      client_message_id:
        message.metadata
          &.dig("client_message_id")
    }
  end

  # =========================================================
  # SERIALIZE CONVERSATION
  # =========================================================

  def serialize_conversation(
    conversation,
    unread_count = 0
  )
    {
      id:
        conversation.id,

      phone_number:
        conversation.phone_number,

      sender_name:
        conversation.sender_name,

      body:
        conversation.body,

      message_type:
        conversation.message_type,

      direction:
        conversation.direction,

      status:
        conversation.status,

      created_at:
        conversation.created_at&.iso8601(6),

      unread_count:
        unread_count
    }
  end

  # =========================================================
  # FIND USER
  # =========================================================

  def find_user
    normalized =
      @phone
        .to_s
        .gsub(/\D/, "")

    return nil if normalized.blank?

    columns =
      %w[phone mobile]
        .select do |column|
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
      "[ADMIN WHATSAPP USER LOOKUP ERROR] " \
      "#{e.class}: #{e.message}"
    )

    nil
  end

  # =========================================================
  # STATUS CACHE
  # =========================================================

  def whatsapp_status_cache_key(message_id)
    "whatsapp:message_status:#{message_id}"
  end

  # =========================================================
  # APPLY STATUS
  # =========================================================

  def apply_status_to_message(
    message,
    status,
    timestamp = nil
  )
    normalized =
      status.to_s.downcase

    return unless WhatsappMessage::STATUSES.include?(normalized)

    status_time =
      case timestamp
      when Time
        timestamp
      when String
        parse_time(timestamp) || Time.current
      when Integer
        Time.at(timestamp)
      else
        Time.current
      end

    current =
      message.status.to_s

    # Never allow:
    #
    # read -> delivered
    # delivered -> sent
    #
    rank = {
      "sent" => 1,
      "delivered" => 2,
      "read" => 3,
      "failed" => 4
    }

    # Failed is terminal unless message is still sent.
    if current == "failed"
      return
    end

    if normalized != "failed" &&
       rank[normalized].to_i < rank[current].to_i
      return
    end

    message.update!(
      status:
        normalized,

      status_updated_at:
        status_time,

      updated_at:
        Time.current
    )
  end

  # =========================================================
  # TIME PARSER
  # =========================================================

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(
      value.to_s
    )
  rescue ArgumentError,
         TypeError
    nil
  end

  # =========================================================
  # NO CACHE
  # =========================================================

  def no_cache!
    response.headers["Cache-Control"] =
      "no-store, no-cache, must-revalidate, max-age=0"

    response.headers["Pragma"] =
      "no-cache"

    response.headers["Expires"] =
      "0"
  end

  # =========================================================
  # ERROR
  # =========================================================

  def render_send_error(
    message,
    status
  )
    if request.format.json?
      no_cache!

      render json: {
        success: false,
        error: message
      }, status: status
    else
      redirect_to(
        admin_whatsapp_conversation_path(
          phone: @phone
        ),
        alert: message
      )
    end
  end

  # =========================================================
  # PHONE
  # =========================================================

  def set_phone
    @phone =
      params[:phone]
        .to_s
        .gsub(/\D/, "")
  end

  # =========================================================
  # ADMIN
  # =========================================================

  def require_admin
    return if current_user&.admin?

    redirect_to(
      root_path,
      alert: "Access denied."
    )
  end
end