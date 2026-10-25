class EbookPaymentsController < ApplicationController
  before_action :authenticate_user!

  # =========================================================
  # CREATE RAZORPAY ORDER
  # =========================================================

  def create
    @ebook = Ebook.published.find(params[:ebook_id])

    # ---------------------------------------------------------
    # FREE E-BOOK
    # ---------------------------------------------------------

    if @ebook.free?
      redirect_to ebook_path(@ebook),
                  alert: "This E-Book is free. No payment is required."
      return
    end

    # ---------------------------------------------------------
    # ALREADY PURCHASED
    # ---------------------------------------------------------

    existing_purchase =
      current_user.ebook_purchases
                  .where(ebook: @ebook)
                  .where(
                    payment_status: "paid",
                    status: "active"
                  )
                  .order(created_at: :desc)
                  .first

    if existing_purchase.present?
      redirect_to ebook_path(@ebook),
                  notice: "You already own this E-Book."
      return
    end

    # ---------------------------------------------------------
    # EXISTING PENDING PURCHASE
    # ---------------------------------------------------------

    pending_purchase =
      current_user.ebook_purchases
                  .where(ebook: @ebook)
                  .where(
                    payment_status: "pending",
                    status: "pending"
                  )
                  .where.not(razorpay_order_id: nil)
                  .order(created_at: :desc)
                  .first

    if pending_purchase.present?
      redirect_to ebook_payment_path(pending_purchase)
      return
    end

    # ---------------------------------------------------------
    # AMOUNT
    # ---------------------------------------------------------

    amount = @ebook.price.to_d

    if amount <= 0
      redirect_to ebook_path(@ebook),
                  alert: "Invalid E-Book price."
      return
    end

    razorpay_amount = (amount * 100).to_i

    if razorpay_amount <= 0
      redirect_to ebook_path(@ebook),
                  alert: "Invalid payment amount."
      return
    end

    # ---------------------------------------------------------
    # CREATE RAZORPAY ORDER
    # ---------------------------------------------------------

    razorpay_order =
      Razorpay::Order.create(
        amount: razorpay_amount,
        currency: "INR",
        receipt:
          "ebook_#{@ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
      )

    # ---------------------------------------------------------
    # CREATE PURCHASE
    # ---------------------------------------------------------

    @purchase =
      current_user.ebook_purchases.create!(
        ebook: @ebook,
        amount: amount,
        original_amount: amount,
        discount_amount: 0,
        final_amount: amount,
        payment_status: "pending",
        status: "pending",
        razorpay_order_id: razorpay_order.id
      )

    redirect_to ebook_payment_path(@purchase)

  rescue Razorpay::Error => e

    Rails.logger.error(
      "EBOOK RAZORPAY ORDER ERROR: #{e.class} - #{e.message}"
    )

    redirect_to ebook_path(@ebook),
                alert: "Unable to create payment. Please try again."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "EBOOK PURCHASE RECORD ERROR: #{e.message}"
    )

    redirect_to ebook_path(@ebook),
                alert: "Unable to create purchase record."

  rescue ActiveRecord::RecordNotFound

    redirect_to ebooks_path,
                alert: "E-Book not found."
  end


  # =========================================================
  # PAYMENT PAGE
  # =========================================================

  def show
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    # ---------------------------------------------------------
    # ALREADY PAID
    # ---------------------------------------------------------

    if @purchase.paid?
      redirect_to ebook_path(@ebook),
                  notice: "You already have access to this E-Book."
      return
    end

    # ---------------------------------------------------------
    # E-BOOK MUST BE PUBLISHED
    # ---------------------------------------------------------

    unless @ebook.status.to_s == "published"
      redirect_to ebooks_path,
                  alert: "This E-Book is currently unavailable."
      return
    end

    # ---------------------------------------------------------
    # FREE E-BOOK
    # ---------------------------------------------------------

    if @ebook.free?
      redirect_to ebook_path(@ebook),
                  alert: "This E-Book is free. No payment is required."
      return
    end

    # ---------------------------------------------------------
    # CURRENT PURCHASE AMOUNT
    #
    # If coupon is applied:
    #   use final_amount
    #
    # Otherwise:
    #   use current E-Book price
    # ---------------------------------------------------------

    current_amount =
      if @purchase.coupon.present?
        @purchase.payable_amount
      else
        @ebook.price.to_d
      end

    if current_amount <= 0
      redirect_to ebook_path(@ebook),
                  alert: "Invalid payment amount."
      return
    end

    razorpay_amount =
      (current_amount * 100).to_i

    if razorpay_amount <= 0
      redirect_to ebook_path(@ebook),
                  alert: "Invalid payment amount."
      return
    end

    # ---------------------------------------------------------
    # CHECK EXISTING RAZORPAY ORDER
    # ---------------------------------------------------------

    current_order_amount =
      begin
        if @purchase.razorpay_order_id.present?
          Razorpay::Order.fetch(
            @purchase.razorpay_order_id
          ).amount.to_i
        end
      rescue StandardError
        nil
      end

    # ---------------------------------------------------------
    # SYNCHRONIZE PURCHASE PRICE
    #
    # No coupon:
    #   purchase should equal current E-Book price
    #
    # Coupon:
    #   keep the coupon-calculated final price
    # ---------------------------------------------------------

    if @purchase.coupon.blank?

      if @purchase.amount.to_d != current_amount ||
         @purchase.original_amount.to_d != current_amount ||
         @purchase.final_amount.to_d != current_amount ||
         @purchase.discount_amount.to_d != 0

        @purchase.update!(
          amount: current_amount,
          original_amount: current_amount,
          discount_amount: 0,
          final_amount: current_amount
        )
      end

    else

      # -------------------------------------------------------
      # Recalculate coupon against current E-Book price.
      #
      # This prevents an old coupon calculation from being
      # used if the E-Book price has changed.
      # -------------------------------------------------------

      coupon = @purchase.coupon

      unless coupon.usable? &&
             coupon.available_for_user?(current_user) &&
             coupon.applicable_to?(@ebook)

        @purchase.remove_coupon!

        current_amount = @ebook.price.to_d
        razorpay_amount = (current_amount * 100).to_i
      else

        base_price = @ebook.price.to_d

        discount =
          coupon.discount_for(base_price)

        final_price =
          base_price - discount

        if @purchase.original_amount.to_d != base_price ||
           @purchase.discount_amount.to_d != discount ||
           @purchase.final_amount.to_d != final_price ||
           @purchase.amount.to_d != final_price

          @purchase.update!(
            original_amount: base_price,
            discount_amount: discount,
            final_amount: final_price,
            amount: final_price
          )

          current_amount = final_price
          razorpay_amount = (final_price * 100).to_i
        end
      end
    end

    # ---------------------------------------------------------
    # CHECK AGAINST RAZORPAY ORDER
    # ---------------------------------------------------------

    if current_order_amount != razorpay_amount

      razorpay_order =
        Razorpay::Order.create(
          amount: razorpay_amount,
          currency: "INR",
          receipt:
            "ebook_#{@ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
        )

      @purchase.update!(
        amount: current_amount,
        final_amount: current_amount,
        razorpay_order_id: razorpay_order.id
      )
    end
  end


  # =========================================================
  # APPLY COUPON
  # =========================================================

  def apply_coupon
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    # ---------------------------------------------------------
    # ALREADY PAID
    # ---------------------------------------------------------

    if @purchase.paid?
      redirect_to ebook_payment_path(@purchase),
                  alert: "This payment has already been completed."
      return
    end

    # ---------------------------------------------------------
    # FREE E-BOOK
    # ---------------------------------------------------------

    if @ebook.free?
      redirect_to ebook_payment_path(@purchase),
                  alert: "This E-Book is free. No coupon is required."
      return
    end

    # ---------------------------------------------------------
    # COUPON CODE
    # ---------------------------------------------------------

    code =
      params[:coupon_code]
          .to_s
          .strip
          .upcase

    if code.blank?
      redirect_to ebook_payment_path(@purchase),
                  alert: "Please enter a coupon code."
      return
    end

    # ---------------------------------------------------------
    # FIND COUPON
    # ---------------------------------------------------------

    coupon =
      Coupon
        .where("LOWER(code) = ?", code.downcase)
        .first

    unless coupon.present?
      redirect_to ebook_payment_path(@purchase),
                  alert: "Invalid coupon code."
      return
    end

    # ---------------------------------------------------------
    # COUPON AVAILABLE FOR USER
    # ---------------------------------------------------------

    unless coupon.available_for_user?(current_user)
      redirect_to ebook_payment_path(@purchase),
                  alert: "This coupon is not available for you."
      return
    end

    # ---------------------------------------------------------
    # COUPON VALID FOR THIS E-BOOK
    # ---------------------------------------------------------

    unless coupon.applicable_to?(@ebook)
      redirect_to ebook_payment_path(@purchase),
                  alert: "This coupon is not valid for this E-Book."
      return
    end

    # ---------------------------------------------------------
    # APPLY COUPON
    # ---------------------------------------------------------

    @purchase.apply_coupon!(coupon)

    # ---------------------------------------------------------
    # CREATE NEW RAZORPAY ORDER
    #
    # Existing order may have original price.
    # We need a new order using discounted price.
    # ---------------------------------------------------------

    final_amount =
      @purchase.payable_amount

    razorpay_amount =
      (final_amount * 100).to_i

    if razorpay_amount <= 0
      redirect_to ebook_payment_path(@purchase),
                  alert: "Invalid discounted payment amount."
      return
    end

    razorpay_order =
      Razorpay::Order.create(
        amount: razorpay_amount,
        currency: "INR",
        receipt:
          "ebook_#{@ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
      )

    @purchase.update!(
      razorpay_order_id: razorpay_order.id
    )

    redirect_to ebook_payment_path(@purchase),
                notice:
                  "Coupon applied successfully. " \
                  "You saved ₹#{format('%.2f', @purchase.coupon_discount)}."

  rescue Razorpay::Error => e

    Rails.logger.error(
      "EBOOK COUPON RAZORPAY ORDER ERROR: " \
      "#{e.class} - #{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  "Coupon was applied, but we could not create the payment order. " \
                  "Please try again."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "EBOOK COUPON APPLY ERROR: " \
      "#{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  e.record.errors.full_messages.to_sentence

  rescue ActiveRecord::RecordNotFound

    redirect_to ebooks_path,
                alert: "E-Book purchase not found."

  rescue StandardError => e

    Rails.logger.error(
      "EBOOK COUPON APPLY UNEXPECTED ERROR: " \
      "#{e.class} - #{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  "Unable to apply coupon. Please try again."
  end


  # =========================================================
  # REMOVE COUPON
  # =========================================================

  def remove_coupon
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    # ---------------------------------------------------------
    # ALREADY PAID
    # ---------------------------------------------------------

    if @purchase.paid?
      redirect_to ebook_payment_path(@purchase),
                  alert: "Payment has already been completed."
      return
    end

    # ---------------------------------------------------------
    # REMOVE COUPON
    # ---------------------------------------------------------

    @purchase.remove_coupon!

    final_amount =
      @purchase.payable_amount

    razorpay_amount =
      (final_amount * 100).to_i

    if razorpay_amount <= 0
      redirect_to ebook_payment_path(@purchase),
                  alert: "Invalid payment amount."
      return
    end

    # ---------------------------------------------------------
    # CREATE NEW RAZORPAY ORDER
    # ---------------------------------------------------------

    razorpay_order =
      Razorpay::Order.create(
        amount: razorpay_amount,
        currency: "INR",
        receipt:
          "ebook_#{@ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
      )

    @purchase.update!(
      razorpay_order_id: razorpay_order.id
    )

    redirect_to ebook_payment_path(@purchase),
                notice: "Coupon removed successfully."

  rescue Razorpay::Error => e

    Rails.logger.error(
      "EBOOK REMOVE COUPON RAZORPAY ERROR: " \
      "#{e.class} - #{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  "Coupon was removed, but we could not refresh the payment order."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "EBOOK REMOVE COUPON RECORD ERROR: " \
      "#{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  e.record.errors.full_messages.to_sentence

  rescue ActiveRecord::RecordNotFound

    redirect_to ebooks_path,
                alert: "E-Book purchase not found."

  rescue StandardError => e

    Rails.logger.error(
      "EBOOK REMOVE COUPON ERROR: " \
      "#{e.class} - #{e.message}"
    )

    redirect_to ebook_payment_path(@purchase),
                alert:
                  "Unable to remove coupon. Please try again."
  end


  # =========================================================
  # VERIFY RAZORPAY PAYMENT
  # =========================================================

def verify
  @purchase = current_user.ebook_purchases.find(params[:id])
  @ebook = @purchase.ebook

  payment_id = params[:razorpay_payment_id].to_s.strip
  order_id = params[:razorpay_order_id].to_s.strip
  signature = params[:razorpay_signature].to_s.strip

  if payment_id.blank? || order_id.blank? || signature.blank?
    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment verification information is missing."
    return
  end

  unless @purchase.razorpay_order_id.to_s == order_id
    Rails.logger.warn(
      "[EBOOK PAYMENT] Order mismatch for purchase #{@purchase.id}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment order does not match."
    return
  end

  # If already paid, do not create another completion or notification.
  if @purchase.paid?
    redirect_to ebook_payment_success_path(@purchase),
                notice: "Payment has already been verified."
    return
  end

  completed_purchase = EbookPaymentCompletionService.call(
    purchase: @purchase,
    payment_id: payment_id,
    order_id: order_id,
    signature: signature
  )

  @purchase = completed_purchase.reload

  Rails.logger.info(
    "[EBOOK PAYMENT] Verified successfully: " \
    "purchase=#{@purchase.id}, ebook=#{@ebook.id}, " \
    "payment=#{payment_id}, order=#{order_id}"
  )

  redirect_to ebook_payment_success_path(@purchase),
              notice: "Payment successful. You now have access to this E-Book."

rescue EbookPaymentCompletionService::Error => e
  Rails.logger.error(
    "[EBOOK PAYMENT] Verification failed: " \
    "purchase=#{@purchase&.id}, error=#{e.class}: #{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert: "Payment could not be verified. If money was deducted, please contact administration."

rescue ActiveRecord::RecordNotFound
  redirect_to ebooks_path,
              alert: "E-Book purchase not found."

rescue ActiveRecord::RecordInvalid => e
  Rails.logger.error(
    "[EBOOK PAYMENT] Record error: " \
    "purchase=#{@purchase&.id}, error=#{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert: "Payment could not be recorded. If money was deducted, please contact administration."

rescue StandardError => e
  Rails.logger.error(
    "[EBOOK PAYMENT] Unexpected verification error: " \
    "purchase=#{@purchase&.id}, error=#{e.class}: #{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert: "We could not confirm your payment yet. If money was deducted, please contact administration."
end


  # =========================================================
  # SUCCESS
  # =========================================================

  def success
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    unless @purchase.paid?
      redirect_to ebook_payment_path(@purchase),
                  alert:
                    "Payment has not been completed yet."
      return
    end
  end


  # =========================================================
  # FAILED
  # =========================================================

  def failed
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook
  end
end