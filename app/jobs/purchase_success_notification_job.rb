
class PurchaseSuccessNotificationJob < ApplicationJob
  queue_as :default

  def perform(purchase_type, purchase_id)
    Rails.logger.info(
      "[PURCHASE NOTIFICATION] Job started: " \
      "type=#{purchase_type} id=#{purchase_id}"
    )

    purchase_class =
      case purchase_type.to_s
      when "EbookPurchase"
        EbookPurchase
      when "TestSeriesPurchase"
        TestSeriesPurchase
      else
        raise ArgumentError,
              "Unsupported purchase type: #{purchase_type}"
      end

    purchase = purchase_class.find(purchase_id)

    unless purchase.paid?
      Rails.logger.warn(
        "[PURCHASE NOTIFICATION] Skipped unpaid purchase: " \
        "type=#{purchase_type} id=#{purchase_id}"
      )
      return
    end

    # Email notification
    if purchase.success_email_sent_at.blank?
      begin
        email_sent =
          BrevoPurchaseNotificationService
            .new(purchase)
            .send_success_email

        if email_sent
          purchase.update!(success_email_sent_at: Time.current)
          Rails.logger.info(
            "[PURCHASE NOTIFICATION] Email accepted: " \
            "type=#{purchase_type} id=#{purchase_id}"
          )
        else
          Rails.logger.warn(
            "[PURCHASE NOTIFICATION] Email skipped: " \
            "type=#{purchase_type} id=#{purchase_id}; " \
            "check user email"
          )
        end
      rescue StandardError => e
        Rails.logger.error(
          "[PURCHASE NOTIFICATION] Email error: " \
          "type=#{purchase_type} id=#{purchase_id} " \
          "error=#{e.class}: #{e.message}"
        )
      end
    else
      Rails.logger.info(
        "[PURCHASE NOTIFICATION] Email already marked sent: " \
        "type=#{purchase_type} id=#{purchase_id}"
      )
    end

    # WhatsApp notification
    if purchase.reload.success_whatsapp_sent_at.blank?
      begin
        whatsapp_sent =
          MetaWhatsappPurchaseNotificationService
            .new(purchase)
            .send_success_message

        if whatsapp_sent
          purchase.update!(success_whatsapp_sent_at: Time.current)
          Rails.logger.info(
            "[PURCHASE NOTIFICATION] WhatsApp accepted: " \
            "type=#{purchase_type} id=#{purchase_id}"
          )
        else
          Rails.logger.warn(
            "[PURCHASE NOTIFICATION] WhatsApp skipped: " \
            "type=#{purchase_type} id=#{purchase_id}; " \
            "check user mobile"
          )
        end
      rescue StandardError => e
        Rails.logger.error(
          "[PURCHASE NOTIFICATION] WhatsApp error: " \
          "type=#{purchase_type} id=#{purchase_id} " \
          "error=#{e.class}: #{e.message}"
        )
      end
    else
      Rails.logger.info(
        "[PURCHASE NOTIFICATION] WhatsApp already marked sent: " \
        "type=#{purchase_type} id=#{purchase_id}"
      )
    end

    Rails.logger.info(
      "[PURCHASE NOTIFICATION] Job finished: " \
      "type=#{purchase_type} id=#{purchase_id}"
    )
  end
end
