class RazorpayWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_forgery_protection

  # --------------------------------------------------
  # POST /razorpay/webhook
  # --------------------------------------------------

  def payment
    raw_body =
      request.raw_post

    webhook_signature =
      request.headers["X-Razorpay-Signature"].to_s.strip

    webhook_secret =
      ENV.fetch("RAZORPAY_WEBHOOK_SECRET")

    if webhook_signature.blank?
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Missing signature."
      )

      head :unauthorized
      return
    end

    generated_signature =
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("SHA256"),
        webhook_secret,
        raw_body
      )

    unless ActiveSupport::SecurityUtils.secure_compare(
      generated_signature,
      webhook_signature
    )
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Invalid signature."
      )

      head :unauthorized
      return
    end

    payload =
      JSON.parse(raw_body)

    event =
      payload["event"].to_s

    Rails.logger.info(
      "[RAZORPAY WEBHOOK] Event: #{event}"
    )

    # --------------------------------------------------
    # WE ONLY COMPLETE CAPTURED PAYMENTS
    # --------------------------------------------------

    unless %w[
      payment.captured
      order.paid
    ].include?(event)

      head :ok
      return
    end

    payment_entity =
      payload.dig(
        "payload",
        "payment",
        "entity"
      )

    # order.paid can also be handled through order entity
    if payment_entity.blank?
      payment_entity =
        payload.dig(
          "payload",
          "order",
          "entity"
        )
    end

    if payment_entity.blank?
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Payment/order entity missing."
      )

      head :ok
      return
    end

    razorpay_payment_id =
      payment_entity["id"].to_s.strip

    razorpay_order_id =
      payment_entity["order_id"].to_s.strip

    # --------------------------------------------------
    # order.paid may not contain payment entity ID
    # --------------------------------------------------

    if razorpay_order_id.blank?
      razorpay_order_id =
        payment_entity["id"].to_s.strip
    end

    if razorpay_payment_id.blank? ||
       razorpay_order_id.blank?

      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Payment ID/order ID missing."
      )

      head :ok
      return
    end

    payment =
      Payment.find_by(
        razorpay_order_id: razorpay_order_id
      )

    unless payment
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Local payment not found for order #{razorpay_order_id}."
      )

      # Return 200 so Razorpay does not repeatedly retry
      # an event that does not belong to a local payment.
      head :ok
      return
    end

    result =
      RazorpayPaymentCompletionService.call(
        payment: payment,
        razorpay_payment_id: razorpay_payment_id,
        razorpay_order_id: razorpay_order_id
      )

    unless result.success
      Rails.logger.error(
        "[RAZORPAY WEBHOOK] Payment completion failed: #{result.message}"
      )

      # We return 200 because the event was received and
      # logged. A failed business validation should not
      # blindly trigger endless webhook retries.
      head :ok
      return
    end

    Rails.logger.info(
      "[RAZORPAY WEBHOOK] Payment #{payment.id} completed successfully."
    )

    head :ok

  rescue JSON::ParserError => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] Invalid JSON: #{e.message}"
    )

    head :bad_request

  rescue KeyError => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] Missing configuration: #{e.message}"
    )

    head :internal_server_error

  rescue StandardError => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] #{e.class}: #{e.message}"
    )

    Rails.logger.error(
      e.backtrace.first(20).join("\n")
    )

    head :internal_server_error
  end
end