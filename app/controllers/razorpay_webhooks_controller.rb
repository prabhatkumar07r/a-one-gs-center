
class RazorpayWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_forgery_protection

  # POST /razorpay/webhook
  def payment
    raw_body = request.raw_post
    signature = request.headers["X-Razorpay-Signature"].to_s.strip
    secret = ENV.fetch("RAZORPAY_WEBHOOK_SECRET")

    if signature.blank?
      Rails.logger.warn("[RAZORPAY WEBHOOK] Missing signature.")
      return head :unauthorized
    end

    expected_signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("SHA256"),
      secret,
      raw_body
    )

    unless ActiveSupport::SecurityUtils.secure_compare(
      expected_signature,
      signature
    )
      Rails.logger.warn("[RAZORPAY WEBHOOK] Invalid signature.")
      return head :unauthorized
    end

    payload = JSON.parse(raw_body)
    event = payload["event"].to_s

    Rails.logger.info("[RAZORPAY WEBHOOK] Event: #{event}")

    # Only process payment completion events.
    unless %w[payment.captured order.paid].include?(event)
      return head :ok
    end

    # payment.captured contains a payment entity.
    # order.paid identifies the order; its ID is NOT a payment ID.
    if event == "payment.captured"
      entity = payload.dig("payload", "payment", "entity")
      razorpay_payment_id = entity&.dig("id").to_s.strip
      razorpay_order_id = entity&.dig("order_id").to_s.strip
    else
      entity = payload.dig("payload", "order", "entity")
      razorpay_payment_id = nil
      razorpay_order_id = entity&.dig("id").to_s.strip
    end

    if razorpay_order_id.blank?
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Order ID missing for event #{event}."
      )
      return head :ok
    end

    # Preserve the existing course-payment completion flow.
    course_payment = Payment.find_by(
      razorpay_order_id: razorpay_order_id
    )

    if course_payment
      result = RazorpayPaymentCompletionService.call(
        payment: course_payment,
        razorpay_payment_id: razorpay_payment_id.presence,
        razorpay_order_id: razorpay_order_id
      )

      unless result.success
        Rails.logger.error(
          "[RAZORPAY WEBHOOK] Course payment completion failed: " \
          "#{result.message}"
        )
      end

      return head :ok
    end

    # E-book payments are stored in EbookPurchase, not Payment.
    ebook_purchase = EbookPurchase.find_by(
      razorpay_order_id: razorpay_order_id
    )

    unless ebook_purchase
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] No local course or e-book purchase " \
        "found for order #{razorpay_order_id}."
      )
      return head :ok
    end

    complete_ebook_purchase!(
      ebook_purchase,
      razorpay_payment_id,
      razorpay_order_id
    )

    head :ok

  rescue JSON::ParserError => e
    Rails.logger.error("[RAZORPAY WEBHOOK] Invalid JSON: #{e.message}")
    head :bad_request

  rescue KeyError => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] Missing configuration: #{e.message}"
    )
    head :internal_server_error

  rescue Razorpay::Error => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] Razorpay error: #{e.class}: #{e.message}"
    )
    head :internal_server_error

  rescue StandardError => e
    Rails.logger.error(
      "[RAZORPAY WEBHOOK] #{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    head :internal_server_error
  end

  private

  def complete_ebook_purchase!(purchase, payment_id, order_id)
    # order.paid may not contain the payment ID.
    payment_id = find_captured_payment_id(order_id) if payment_id.blank?

    if payment_id.blank?
      raise EbookPaymentCompletionService::Error,
            "No unique captured payment found for e-book order #{order_id}."
    end

    EbookPaymentCompletionService.call(
      purchase: purchase,
      payment_id: payment_id,
      order_id: order_id
    )
  end
  def find_captured_payment_id(order_id)
    order = Razorpay::Order.fetch(order_id)
    payments = order.payments

    items = payments.respond_to?(:items) ? payments.items : []
    captured = Array(items).select do |item|
      item["status"].to_s.downcase == "captured"
    end

    if captured.length != 1
      Rails.logger.warn(
        "[RAZORPAY WEBHOOK] Expected one captured payment for order " \
        "#{order_id}, found #{captured.length}."
      )
      return nil
    end

    captured.first["id"].to_s
  end
end

