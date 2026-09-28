class Admin::WhatsappMessagesController < ApplicationController
  before_action :require_admin
  before_action :set_phone, only: %i[conversation send_message]

  def index
    @conversations = WhatsappMessage
      .select(
        "DISTINCT ON (phone_number) whatsapp_messages.*"
      )
      .order(
        "phone_number",
        created_at: :desc
      )

    @conversations = @conversations
      .sort_by(&:created_at)
      .reverse

    @unread_count = WhatsappMessage
      .incoming
      .unread
      .count
  end

  def conversation
    @messages = WhatsappMessage
      .where(phone_number: @phone)
      .order(created_at: :asc)

    WhatsappMessage
      .where(
        phone_number: @phone,
        direction: "incoming",
        read_at: nil
      )
      .update_all(read_at: Time.current)

    @user = @messages
      .where.not(user_id: nil)
      .last
      &.user
  end

  def send_message
    body = params[:body].to_s.strip

    if body.blank?
      redirect_to(
        admin_whatsapp_conversation_path(
          phone: @phone
        ),
        alert: "Message cannot be blank."
      )
      return
    end

    response =
      MetaWhatsappChatService.send_text(
        to: @phone,
        body: body
      )

    whatsapp_message_id =
      response.dig(
        "messages",
        0,
        "id"
      ).to_s

    WhatsappMessage.create!(
      user: find_user,
      phone_number: @phone,
      sender_name: "A One GS Center",
      whatsapp_message_id:
        whatsapp_message_id.presence ||
        "local-#{SecureRandom.uuid}",
      message_type: "text",
      body: body,
      direction: "outgoing",
      whatsapp_timestamp: Time.current,
      metadata: {
        api_response: response
      },
      raw_payload: response
    )

    redirect_to(
      admin_whatsapp_conversation_path(
        phone: @phone
      ),
      notice: "Message sent successfully."
    )
  rescue MetaWhatsappChatService::Error => e
    Rails.logger.error(
      "[ADMIN WHATSAPP SEND ERROR] #{e.class}: #{e.message}"
    )

    redirect_to(
      admin_whatsapp_conversation_path(
        phone: @phone
      ),
      alert: e.message
    )
  rescue StandardError => e
    Rails.logger.error(
      "[ADMIN WHATSAPP SEND ERROR] #{e.class}: #{e.message}"
    )

    redirect_to(
      admin_whatsapp_conversation_path(
        phone: @phone
      ),
      alert: "Unable to send WhatsApp message."
    )
  end

  private

  def set_phone
    @phone = params[:phone].to_s.gsub(/\D/, "")
  end

  def find_user
    normalized = @phone

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
      "[ADMIN WHATSAPP USER LOOKUP ERROR] " \
      "#{e.class}: #{e.message}"
    )

    nil
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path,
                  alert: "Access denied."
    end
  end
end