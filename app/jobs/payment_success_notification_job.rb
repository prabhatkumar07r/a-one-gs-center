class PaymentSuccessNotificationJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment =
      Payment
        .includes(
          enrollment: [
            :user,
            :course
          ]
        )
        .find(payment_id)

    # =======================================================
    # Only send for successfully paid payment
    # =======================================================

    return unless payment.paid?

    # =======================================================
    # EMAIL — BREVO
    # =======================================================

    if payment.success_email_sent_at.blank?

      begin

        BrevoPaymentNotificationService
          .send_success_email(payment)

        payment.update!(
          success_email_sent_at: Time.current
        )

      rescue StandardError => e

        Rails.logger.error(
          "[PAYMENT SUCCESS EMAIL] " \
          "#{e.class}: #{e.message}"
        )

        raise
      end
    end

    # =======================================================
    # WHATSAPP — META WHATSAPP CLOUD API
    # =======================================================

    if payment.success_whatsapp_sent_at.blank?

      begin

        MetaWhatsappNotificationService
          .send_payment_success(payment)

        payment.update!(
          success_whatsapp_sent_at: Time.current
        )

      rescue StandardError => e

        Rails.logger.error(
          "[PAYMENT SUCCESS WHATSAPP] " \
          "#{e.class}: #{e.message}"
        )

        raise
      end
    end
  end
end