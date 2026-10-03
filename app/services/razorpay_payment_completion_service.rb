class RazorpayPaymentCompletionService
  Result = Struct.new(
    :success,
    :already_paid,
    :payment,
    :message,
    keyword_init: true
  )

  def self.call(
    payment:,
    razorpay_payment_id: nil,
    razorpay_order_id:
  )
    new(
      payment: payment,
      razorpay_payment_id: razorpay_payment_id,
      razorpay_order_id: razorpay_order_id
    ).call
  end

  def initialize(
    payment:,
    razorpay_payment_id: nil,
    razorpay_order_id:
  )
    @payment = payment
    @razorpay_payment_id = razorpay_payment_id.to_s.strip
    @razorpay_order_id = razorpay_order_id.to_s.strip
  end

  def call
    return failure("Order ID is missing.") if @razorpay_order_id.blank?

    unless @payment.razorpay_order_id.to_s == @razorpay_order_id
      return failure(
        "Razorpay order does not match the local payment."
      )
    end

    razorpay_payment_id =
      @razorpay_payment_id.presence ||
      find_captured_payment_id

    if razorpay_payment_id.blank?
      return failure(
        "No captured Razorpay payment was found for this order."
      )
    end

    @razorpay_payment_id =
      razorpay_payment_id.to_s.strip

    razorpay_payment =
      Razorpay::Payment.fetch(
        @razorpay_payment_id
      )

    razorpay_status =
      razorpay_payment.status.to_s.downcase

    unless razorpay_status == "captured"
      return failure(
        "Razorpay payment is not captured. " \
        "Current status: #{razorpay_status.presence || "unknown"}"
      )
    end

    razorpay_order_id_from_api =
      razorpay_payment.order_id.to_s.strip

    unless razorpay_order_id_from_api ==
           @payment.razorpay_order_id.to_s
      return failure(
        "Razorpay payment/order mismatch."
      )
    end

    razorpay_amount_paise =
      razorpay_payment.amount.to_i

    local_amount_paise =
      (@payment.amount.to_d * 100).round.to_i

    unless razorpay_amount_paise ==
           local_amount_paise
      return failure(
        "Payment amount mismatch. " \
        "Local: #{local_amount_paise} paise, " \
        "Razorpay: #{razorpay_amount_paise} paise."
      )
    end

    notification_needed = false
    already_paid = false

    Payment.transaction do
      locked_payment =
        Payment.lock.find(@payment.id)

      if locked_payment.paid?
        already_paid = true
        next
      end

      enrollment =
        locked_payment.enrollment

      fee =
        enrollment.fee ||
        enrollment.build_fee(
          user: enrollment.user,
          course: enrollment.course
        )

      locked_payment.update!(
        status: "paid",
        razorpay_payment_id: @razorpay_payment_id
      )

      fee.total_fee =
        enrollment.course.fee.to_d

      fee.discount_amount =
        enrollment.discount_amount.to_d

      fee.paid_amount =
        fee.paid_amount.to_d +
        locked_payment.amount.to_d

      fee.save!

      if enrollment.coupon.present?
        coupon = enrollment.coupon

        unless coupon.already_used_by?(enrollment.user)
          CouponUsage.create!(
            coupon: coupon,
            user: enrollment.user,
            purchasable: enrollment,
            discount_amount:
              enrollment.discount_amount.to_d,
            used_at: Time.current
          )
        end

        coupon.update!(
          used_count: coupon.coupon_usages.count
        )
      end

      enrollment.update!(
        status: "Approved"
      )

      notification_needed = true
    end

    if notification_needed
      PaymentSuccessNotificationJob.perform_later(
        @payment.id
      )
    end

    if already_paid
      Result.new(
        success: true,
        already_paid: true,
        payment: @payment,
        message: "Payment has already been verified."
      )
    else
      Result.new(
        success: true,
        already_paid: false,
        payment: @payment,
        message: "Payment successfully verified."
      )
    end

  rescue Razorpay::Error => e
    Rails.logger.error(
      "[RAZORPAY COMPLETION] Razorpay error: " \
      "#{e.class}: #{e.message}"
    )

    failure(
      "Razorpay payment verification failed."
    )

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      "[RAZORPAY COMPLETION] Record validation failed: " \
      "#{e.message}"
    )

    failure(
      "Payment could not be completed."
    )

  rescue StandardError => e
    Rails.logger.error(
      "[RAZORPAY COMPLETION] #{e.class}: #{e.message}"
    )

    Rails.logger.error(
      e.backtrace.first(20).join("\n")
    )

    failure(
      "Payment verification failed."
    )
  end

  private

  def find_captured_payment_id
    order =
      Razorpay::Order.fetch(
        @razorpay_order_id
      )

    payments =
      order.payments

    payment_items =
      if payments.respond_to?(:items)
        payments.items
      else
        []
      end

    payment_items =
      Array(payment_items)

    captured_payments =
      payment_items.select do |payment|
        payment["status"].to_s.downcase == "captured"
      end

    return nil if captured_payments.empty?

    if captured_payments.length > 1
      Rails.logger.warn(
        "[RAZORPAY COMPLETION] " \
        "Multiple captured payments found for order " \
        "#{@razorpay_order_id}: " \
        "#{captured_payments.map { |p| p["id"] }.join(", ")}"
      )

      return nil
    end

    captured_payments.first["id"].to_s
  end

  def failure(message)
    Result.new(
      success: false,
      already_paid: false,
      payment: @payment,
      message: message
    )
  end
end
