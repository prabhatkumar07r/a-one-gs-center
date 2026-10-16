class EbookPaymentCompletionService
  class Error < StandardError; end

  def self.call(purchase:, payment_id:, order_id:, signature: nil)
    new(
      purchase: purchase,
      payment_id: payment_id,
      order_id: order_id,
      signature: signature
    ).call
  end

  def initialize(purchase:, payment_id:, order_id:, signature: nil)
    @purchase = purchase
    @payment_id = payment_id.to_s.strip
    @order_id = order_id.to_s.strip
    @signature = signature.to_s.strip.presence
  end

  def call
    if @payment_id.blank? || @order_id.blank?
      raise Error, "Payment ID or order ID is missing."
    end

    unless @purchase.razorpay_order_id.to_s == @order_id
      raise Error, "E-book purchase/order ID mismatch."
    end

    payment = fetch_payment!

    unless payment.order_id.to_s == @order_id
      raise Error, "Razorpay payment/order mismatch."
    end

    unless payment.status.to_s.downcase == "captured"
      raise Error, "Razorpay payment is not captured."
    end

    unless payment.currency.to_s.upcase == "INR"
      raise Error, "Razorpay payment currency is not INR."
    end

    EbookPurchase.transaction do
      purchase = EbookPurchase.lock.find(@purchase.id)

      unless purchase.razorpay_order_id.to_s == @order_id
        raise Error, "E-book purchase/order ID mismatch."
      end

      expected_amount = (purchase.payable_amount.to_d * 100).round.to_i
      actual_amount = payment.amount.to_i

      unless actual_amount == expected_amount
        raise Error, "E-book payment amount mismatch."
      end

      if purchase.paid?
        if purchase.razorpay_payment_id.present? &&
           purchase.razorpay_payment_id != @payment_id
          raise Error, "Purchase is already paid with a different payment ID."
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
          razorpay_signature: @signature,
          payment_status: "paid",
          status: "active"
        )
      end

      record_coupon_usage!(purchase)

      purchase
    end
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
      usage_exists = CouponUsage.exists?(purchasable: purchase)

      unless usage_exists
        if coupon.already_used_by?(purchase.user)
          Rails.logger.warn(
            "[EBOOK PAYMENT] Coupon #{coupon.id} was already used " \
            "by user #{purchase.user_id}; no duplicate usage created."
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



