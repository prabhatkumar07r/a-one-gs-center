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

    # Razorpay amount is in paise
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
  @purchase = current_user.ebook_purchases.find(params[:id])
  @ebook = @purchase.ebook

  if @purchase.paid?
    redirect_to ebook_path(@ebook),
                notice: "You already have access to this E-Book."
    return
  end

  unless @ebook.status.to_s == "published"
    redirect_to ebooks_path,
                alert: "This E-Book is currently unavailable."
    return
  end

  if @ebook.free?
    redirect_to ebook_path(@ebook),
                alert: "This E-Book is free. No payment is required."
    return
  end

  # =========================================================
  # CURRENT E-BOOK PRICE
  # =========================================================

  current_amount = @ebook.price.to_d
  razorpay_amount = (current_amount * 100).to_i

  # =========================================================
  # CHECK EXISTING RAZORPAY ORDER
  # =========================================================

  current_order_amount =
    begin
      Razorpay::Order.fetch(
        @purchase.razorpay_order_id
      ).amount.to_i
    rescue StandardError
      nil
    end

  # =========================================================
  # PRICE CHANGED
  # =========================================================

  if @purchase.amount.to_d != current_amount ||
     current_order_amount != razorpay_amount

    razorpay_order =
      Razorpay::Order.create(
        amount: razorpay_amount,
        currency: "INR",
        receipt:
          "ebook_#{@ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
      )

    @purchase.update!(
      amount: current_amount,
      razorpay_order_id: razorpay_order.id
    )
  end
end

  # =========================================================
  # VERIFY RAZORPAY PAYMENT
  # =========================================================

  def verify
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    payment_id = params[:razorpay_payment_id]
    order_id = params[:razorpay_order_id]
    signature = params[:razorpay_signature]

    # ---------------------------------------------------------
    # REQUIRED DATA
    # ---------------------------------------------------------

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to ebook_payment_failed_path(@purchase),
                  alert: "Payment verification information is missing."
      return
    end

    # ---------------------------------------------------------
    # VERIFY ORDER BELONGS TO PURCHASE
    # ---------------------------------------------------------

    unless @purchase.razorpay_order_id == order_id

      Rails.logger.warn(
        "EBOOK PAYMENT ORDER MISMATCH: " \
        "purchase=#{@purchase.id}, " \
        "expected=#{@purchase.razorpay_order_id}, " \
        "received=#{order_id}"
      )

      redirect_to ebook_payment_failed_path(@purchase),
                  alert: "Payment order does not match."
      return
    end

    # ---------------------------------------------------------
    # ALREADY PAID
    # ---------------------------------------------------------

    if @purchase.paid?
      redirect_to ebook_payment_success_path(@purchase),
                  notice: "Payment has already been verified."
      return
    end

    # ---------------------------------------------------------
    # RAZORPAY SIGNATURE VERIFICATION
    # ---------------------------------------------------------

    Razorpay::Utility.verify_payment_signature(
      razorpay_order_id: order_id,
      razorpay_payment_id: payment_id,
      razorpay_signature: signature
    )

    # ---------------------------------------------------------
    # SAVE PAYMENT
    # ---------------------------------------------------------

    ActiveRecord::Base.transaction do
      @purchase.update!(
        razorpay_payment_id: payment_id,
        razorpay_signature: signature,
        payment_status: "paid",
        status: "active"
      )
    end

    redirect_to ebook_payment_success_path(@purchase),
                notice: "Payment successful. You now have access to this E-Book."

  rescue Razorpay::SignatureVerificationError

    Rails.logger.error(
      "EBOOK RAZORPAY SIGNATURE VERIFICATION FAILED: " \
      "purchase=#{@purchase&.id}"
    )

    @purchase&.update(
      payment_status: "failed",
      status: "failed"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment verification failed."

  rescue ActiveRecord::RecordNotFound

    redirect_to ebooks_path,
                alert: "E-Book purchase not found."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "EBOOK PAYMENT RECORD ERROR: #{e.message}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert:
                  "Payment was received but could not be recorded. " \
                  "Please contact administration."

  rescue StandardError => e

    Rails.logger.error(
      "EBOOK RAZORPAY VERIFY ERROR: #{e.class} - #{e.message}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Something went wrong while verifying payment."
  end


  # =========================================================
  # SUCCESS
  # =========================================================

  def success
    @purchase =
      current_user.ebook_purchases.find(params[:id])

    @ebook = @purchase.ebook

    # ---------------------------------------------------------
    # SECURITY CHECK
    # ---------------------------------------------------------

    unless @purchase.paid?
      redirect_to ebook_payment_path(@purchase),
                  alert: "Payment has not been completed yet."
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