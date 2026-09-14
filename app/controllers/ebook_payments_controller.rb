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

 # =========================================================
# VERIFY RAZORPAY PAYMENT
# =========================================================

def verify
  @purchase =
    current_user.ebook_purchases.find(params[:id])

  @ebook = @purchase.ebook

  payment_id = params[:razorpay_payment_id].to_s.strip
  order_id   = params[:razorpay_order_id].to_s.strip
  signature  = params[:razorpay_signature].to_s.strip

  # ---------------------------------------------------------
  # REQUIRED DATA
  # ---------------------------------------------------------

  if payment_id.blank? || order_id.blank? || signature.blank?
    Rails.logger.warn(
      "EBOOK PAYMENT VERIFICATION DATA MISSING: " \
      "purchase=#{@purchase.id}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment verification information is missing."
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
  # VERIFY ORDER BELONGS TO PURCHASE
  # ---------------------------------------------------------

  expected_order_id = @purchase.razorpay_order_id.to_s.strip

  unless expected_order_id.present? && expected_order_id == order_id
    Rails.logger.warn(
      "EBOOK PAYMENT ORDER MISMATCH: " \
      "purchase=#{@purchase.id}, " \
      "expected=#{expected_order_id}, " \
      "received=#{order_id}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment order does not match."
    return
  end

  # ---------------------------------------------------------
  # VERIFY RAZORPAY SIGNATURE
  # ---------------------------------------------------------

  Razorpay::Utility.verify_payment_signature(
    razorpay_order_id: order_id,
    razorpay_payment_id: payment_id,
    razorpay_signature: signature
  )

  # ---------------------------------------------------------
  # FETCH ACTUAL PAYMENT FROM RAZORPAY
  # ---------------------------------------------------------

  razorpay_payment =
    Razorpay::Payment.fetch(payment_id)

  # ---------------------------------------------------------
  # VERIFY PAYMENT ORDER
  # ---------------------------------------------------------

  razorpay_payment_order_id =
    razorpay_payment.order_id.to_s.strip

  unless razorpay_payment_order_id == order_id
    Rails.logger.error(
      "EBOOK PAYMENT RAZORPAY ORDER MISMATCH: " \
      "purchase=#{@purchase.id}, " \
      "expected=#{order_id}, " \
      "received=#{razorpay_payment_order_id}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment order verification failed."
    return
  end

  # ---------------------------------------------------------
  # VERIFY CURRENCY
  # ---------------------------------------------------------

  razorpay_currency =
    razorpay_payment.currency.to_s.upcase

  unless razorpay_currency == "INR"
    Rails.logger.error(
      "EBOOK PAYMENT CURRENCY MISMATCH: " \
      "purchase=#{@purchase.id}, " \
      "expected=INR, " \
      "received=#{razorpay_currency}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment currency verification failed."
    return
  end

  # ---------------------------------------------------------
  # VERIFY AMOUNT
  # ---------------------------------------------------------

  expected_amount_paise =
    (@purchase.amount.to_d * 100).to_i

  received_amount_paise =
    razorpay_payment.amount.to_i

  unless received_amount_paise == expected_amount_paise
    Rails.logger.error(
      "EBOOK PAYMENT AMOUNT MISMATCH: " \
      "purchase=#{@purchase.id}, " \
      "expected_paise=#{expected_amount_paise}, " \
      "received_paise=#{received_amount_paise}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment amount verification failed."
    return
  end

  # ---------------------------------------------------------
  # VERIFY PAYMENT STATUS
  # ---------------------------------------------------------

  razorpay_status =
    razorpay_payment.status.to_s.downcase

  unless razorpay_status == "captured"
    Rails.logger.warn(
      "EBOOK PAYMENT NOT CAPTURED: " \
      "purchase=#{@purchase.id}, " \
      "payment=#{payment_id}, " \
      "status=#{razorpay_status}"
    )

    redirect_to ebook_payment_failed_path(@purchase),
                alert: "Payment has not been captured yet."
    return
  end

  # ---------------------------------------------------------
  # SAVE PAYMENT ATOMICALLY
  # ---------------------------------------------------------

  ActiveRecord::Base.transaction do
    @purchase.with_lock do

      # Re-check after acquiring the database lock.
      unless @purchase.paid?
        @purchase.update!(
          razorpay_payment_id: payment_id,
          razorpay_signature: signature,
          payment_status: "paid",
          status: "active"
        )
      end

    end
  end

  # ---------------------------------------------------------
  # SUCCESS LOG
  # ---------------------------------------------------------

  Rails.logger.info(
    "EBOOK PAYMENT VERIFIED SUCCESSFULLY: " \
    "purchase=#{@purchase.id}, " \
    "ebook=#{@ebook.id}, " \
    "payment=#{payment_id}, " \
    "order=#{order_id}, " \
    "amount_paise=#{received_amount_paise}"
  )

  redirect_to ebook_payment_success_path(@purchase),
              notice: "Payment successful. You now have access to this E-Book."

# =========================================================
# SIGNATURE VERIFICATION FAILURE
# =========================================================

rescue Razorpay::SignatureVerificationError => e

  Rails.logger.error(
    "EBOOK RAZORPAY SIGNATURE VERIFICATION FAILED: " \
    "purchase=#{@purchase&.id}, " \
    "error=#{e.message}"
  )

  # Do NOT change the purchase to failed here.
  #
  # A bad verification request does not necessarily mean
  # the actual Razorpay payment failed.

  redirect_to ebook_payment_failed_path(@purchase),
              alert: "Payment verification failed."

# =========================================================
# RAZORPAY API ERROR
# =========================================================

rescue Razorpay::Error => e

  Rails.logger.error(
    "EBOOK RAZORPAY API ERROR DURING VERIFY: " \
    "purchase=#{@purchase&.id}, " \
    "error=#{e.class} - #{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert:
                "Unable to verify the payment with Razorpay. " \
                "If money was deducted, please contact administration."

# =========================================================
# PURCHASE NOT FOUND
# =========================================================

rescue ActiveRecord::RecordNotFound

  redirect_to ebooks_path,
              alert: "E-Book purchase not found."

# =========================================================
# DATABASE ERROR
# =========================================================

rescue ActiveRecord::RecordInvalid => e

  Rails.logger.error(
    "EBOOK PAYMENT RECORD ERROR: " \
    "purchase=#{@purchase&.id}, " \
    "error=#{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert:
                "Payment was received but could not be recorded. " \
                "Please contact administration."

# =========================================================
# UNEXPECTED ERROR
# =========================================================

rescue StandardError => e

  Rails.logger.error(
    "EBOOK RAZORPAY VERIFY ERROR: " \
    "purchase=#{@purchase&.id}, " \
    "error=#{e.class} - #{e.message}"
  )

  redirect_to ebook_payment_failed_path(@purchase),
              alert:
                "Something went wrong while verifying payment. " \
                "Please contact administration."
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