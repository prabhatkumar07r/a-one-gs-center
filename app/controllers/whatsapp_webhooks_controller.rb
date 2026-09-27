class WhatsappWebhooksController < ActionController::API

  # =========================================================
  # META WEBHOOK VERIFICATION
  # =========================================================

  def verify
    mode =
      params["hub.mode"]

    token =
      params["hub.verify_token"]

    challenge =
      params["hub.challenge"]

    verify_token =
      ENV["META_WHATSAPP_VERIFY_TOKEN"]

    if mode == "subscribe" &&
       token.present? &&
       ActiveSupport::SecurityUtils.secure_compare(
         token.to_s,
         verify_token.to_s
       )

      render plain: challenge,
             status: :ok

    else

      render plain: "Forbidden",
             status: :forbidden
    end
  end


  # =========================================================
  # WHATSAPP WEBHOOK EVENTS
  # =========================================================

  def receive
    payload = request.raw_post

    Rails.logger.info(
      "[META WHATSAPP WEBHOOK] #{payload}"
    )

    begin
      data = JSON.parse(payload)

      process_webhook(data)

    rescue JSON::ParserError => e

      Rails.logger.error(
        "[META WHATSAPP WEBHOOK JSON ERROR] #{e.message}"
      )

    rescue StandardError => e

      Rails.logger.error(
        "[META WHATSAPP WEBHOOK ERROR] " \
        "#{e.class}: #{e.message}"
      )
    end

    # Meta expects a successful response.
    head :ok
  end


  private


  # =========================================================
  # PROCESS WHATSAPP WEBHOOK
  # =========================================================

  def process_webhook(data)

    return unless data["object"] == "whatsapp_business_account"

    data.fetch("entry", []).each do |entry|

      entry.fetch("changes", []).each do |change|

        value =
          change["value"]

        next unless value

        # ===================================================
        # MESSAGE STATUS
        # ===================================================

        value.fetch("statuses", []).each do |status|

          message_id =
            status["id"]

          status_value =
            status["status"]

          recipient =
            status["recipient_id"]

          timestamp =
            status["timestamp"]

          Rails.logger.info(
            "[META WHATSAPP STATUS] " \
            "status=#{status_value} " \
            "message_id=#{message_id} " \
            "recipient=#{recipient} " \
            "timestamp=#{timestamp}"
          )

          # Log detailed failure information
          if status_value == "failed"

            Rails.logger.error(
              "[META WHATSAPP FAILED] " \
              "#{status["errors"].inspect}"
            )
          end
        end


        # ===================================================
        # INCOMING MESSAGES
        # ===================================================

        value.fetch("messages", []).each do |message|

          Rails.logger.info(
            "[META WHATSAPP INCOMING MESSAGE] " \
            "#{message.inspect}"
          )

        end

      end

    end
  end
end