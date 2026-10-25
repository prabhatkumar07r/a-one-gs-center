
class EbookPaymentCompletionService
  class Error < StandardError; end

  def self.call(purchase:, payment_id:, order_id:, signature:)
    new(
      purchase: purchase,
      payment_id: payment_id,
      order_id: order_id,
      signature: signature,
      from_webhook: false
    ).call
  end

  # Call only after Razorpay webhook HMAC verification.
  def self.call_from_webhook(purchase:, payment_id:, order_id:)
    new(
      purchase: purchase,
      payment_id: payment_id,
      order_id: order_id,
      signature: nil,
      from_webhook: true
    ).call
  end

  def initialize(
    purchase:,
    payment_id:,
    order_id:,
    signature: nil,
    from_webhook: false
  )
    @purchase = purchase
    @payment_id = payment_id.to_s.strip
    @order_id = order_id.to_s.strip
    @signature = signature.to_s.strip.presence
    @from_webhook = from_webhook
  end

  def call
    raise Error, "Payment ID or order ID is missing." if
      @payment_id.blank? || @order_id.blank?

    unless @purchase.razorpay_order_id.to_s == @order_id
      raise Error, "E-book purchase/order ID mismatch."
    end

    unless @from_webhook
      raise Error, "Payment signature is missing." if @signature.blank?

      begin
        Razorpay::Utility.verify_payment_signature(
          razorpay_order_id: @order_id,
          razorpay_payment_id: @payment_id,
          razorpay_signature: @signature
        )
      rescue Razorpay::SignatureVerificationError
        raise Error, "Payment signature verification failed."
      end
    end

    payment = fetch_payment!

    raise Error, "Razorpay payment/order mismatch." unless
      payment.order_id.to_s == @order_id

    raise Error, "Razorpay payment is not captured." unless
      payment.status.to_s.downcase == "captured"

    raise Error, "Razorpay payment currency is not INR." unless
      payment.currency.to_s.upcase == "INR"

    notification_needed = false

    completed_purchase = EbookPurchase.transaction do
      purchase = EbookPurchase.lock.find(@purchase.id)

      unless purchase.razorpay_order_id.to_s == @order_id
        raise Error, "E-book purchase/order ID mismatch."
      end

      expected_amount =
        (purchase.payable_amount.to_d * 100).round.to_i

      unless payment.amount.to_i == expected_amount
        raise Error, "E-book payment amount mismatch."
      end

      if purchase.paid?
        if purchase.razorpay_payment_id.present? &&
           purchase.razorpay_payment_id != @payment_id
          raise Error,
                "Purchase is already paid with a different payment ID."
        end

        updates = {}

        if purchase.razorpay_payment_id.blank?
          updates[:razorpay_payment_id] = @payment_id
        end

        if purchase.razorpay_signature.blank? && @signature.present?
          updates[:razorpay_signature] = @signature
        end

        purchase.update!(updates) if updates.any?
      else
        purchase.update!(
          razorpay_payment_id: @payment_id,
          razorpay_signature: @signature ||
            purchase.razorpay_signature,
          payment_status: "paid",
          status: "active"
        )

        notification_needed = true
      end

      record_coupon_usage!(purchase)
      purchase
    end

    if notification_needed
      PurchaseSuccessNotificationJob.perform_later(
        "EbookPurchase",
        completed_purchase.id
      )
    end

    completed_purchase
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error(
      "[EBOOK PAYMENT] Completion failed: #{e.class}: #{e.message}"
    )
    raise Error, "Unable to complete E-book payment."
  end

  private

  def fetch_payment!
    Razorpay::Payment.fetch(@payment_id)
  rescue StandardError => e
    Rails.logger.error(
      "[EBOOK PAYMENT] Razorpay fetch failed: #{e.class}"
    )
    raise Error, "Unable to fetch Razorpay payment."
  end

  def record_coupon_usage!(purchase)
    coupon = purchase.coupon
    return unless coupon

    coupon.with_lock do
      unless CouponUsage.exists?(purchasable: purchase)
        if coupon.already_used_by?(purchase.user)
          Rails.logger.warn(
            "[EBOOK PAYMENT] Coupon #{coupon.id} already used by " \
            "user #{purchase.user_id}; skipping duplicate usage."
          )
        else
          CouponUsage.create!(
            coupon: coupon,
            user: purchase.user,
            purchasable: purchase,
            discount_amount: purchase.discount_amount.to_d,
            used_at: Time.current
          )
        end
      end

      coupon.update!(
        used_count: coupon.coupon_usages.count
      )
    end
  end
end
