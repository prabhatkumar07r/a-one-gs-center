class TestSeriesPurchasesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_test_series, only: [:create]

  # ==================================================
  # CREATE TEST SERIES PURCHASE
  # ==================================================
def create

  # ==========================================
  # FREE TEST SERIES
  # ==========================================

  if @test_series.free?

    purchase =
      current_user.test_series_purchases.find_or_initialize_by(
        test_series: @test_series
      )

    purchase.amount = 0
    purchase.payment_status = "paid"
    purchase.status = "Active"

    if purchase.save
      redirect_to test_series_path(@test_series),
                  notice: "Test Series access granted."
    else
      redirect_to test_series_path(@test_series),
                  alert: purchase.errors.full_messages.to_sentence
    end

    return
  end


  # ==========================================
  # ALREADY PURCHASED
  # ==========================================

  existing_purchase =
    current_user.test_series_purchases.find_by(
      test_series: @test_series,
      payment_status: "paid",
      status: "Active"
    )

  if existing_purchase.present?

    redirect_to test_series_path(@test_series),
                notice: "You already have access to this Test Series."

    return
  end


  # ==========================================
  # EXISTING PENDING PURCHASE
  # ==========================================

  existing_purchase =
    current_user.test_series_purchases
                .where(
                  test_series: @test_series,
                  payment_status: "pending",
                  status: "Pending"
                )
                .order(created_at: :desc)
                .first

  if existing_purchase.present? &&
     existing_purchase.razorpay_order_id.present?

    redirect_to test_series_payment_path(existing_purchase),
                notice: "Continue your pending payment."

    return
  end


  # ==========================================
  # VALIDATE PRICE
  # ==========================================

  amount = @test_series.price.to_d

  if amount <= 0

    redirect_to test_series_path(@test_series),
                alert: "Invalid Test Series price."

    return
  end


  # ==========================================
  # CREATE RAZORPAY ORDER
  # ==========================================

  razorpay_order =
    Razorpay::Order.create(
      amount: (amount * 100).to_i,
      currency: "INR",
      receipt: "test_series_#{@test_series.id}_#{current_user.id}_#{Time.current.to_i}"
    )


  # ==========================================
  # CREATE PURCHASE
  # ==========================================

  purchase =
    current_user.test_series_purchases.create!(
      test_series: @test_series,
      amount: amount,
      payment_status: "pending",
      status: "Pending",
      razorpay_order_id: razorpay_order.id
    )


  # ==========================================
  # GO TO PAYMENT PAGE
  # ==========================================

  redirect_to test_series_payment_path(purchase)

rescue Razorpay::Error => e

  Rails.logger.error(
    "TEST SERIES RAZORPAY ERROR: #{e.message}"
  )

  redirect_to test_series_path(@test_series),
              alert: "Unable to create payment. Please try again."

rescue ActiveRecord::RecordInvalid => e

  Rails.logger.error(
    "TEST SERIES PURCHASE ERROR: #{e.message}"
  )

  redirect_to test_series_path(@test_series),
              alert: "Unable to create purchase. Please try again."

rescue StandardError => e

  Rails.logger.error(
    "TEST SERIES PURCHASE ERROR: #{e.class} - #{e.message}"
  )

  redirect_to test_series_path(@test_series),
              alert: "Something went wrong. Please try again."

end
  # ==================================================
  # PAYMENT PAGE
  # ==================================================

  def payment

    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    # Already paid
    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_path(@test_series),
                  notice: "You already have access to this Test Series."
      return
    end

    # Must have Razorpay order
    if @purchase.razorpay_order_id.blank?

      redirect_to test_series_path(@test_series),
                  alert: "Payment order was not created."
      return
    end
  end


  # ==================================================
  # VERIFY PAYMENT
  # ==================================================

  def verify

    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    payment_id = params[:razorpay_payment_id]
    order_id = params[:razorpay_order_id]
    signature = params[:razorpay_signature]

    # ------------------------------------------
    # Validate Razorpay response
    # ------------------------------------------

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to test_series_payment_failed_path(@purchase),
                  alert: "Payment verification information is missing."
      return
    end

    # ------------------------------------------
    # Verify correct order
    # ------------------------------------------

    unless @purchase.razorpay_order_id == order_id

      redirect_to test_series_payment_failed_path(@purchase),
                  alert: "Invalid payment order."
      return
    end

    # ------------------------------------------
    # Already paid
    # ------------------------------------------

    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_payment_success_path(@purchase),
                  notice: "Payment has already been verified."
      return
    end

    # ------------------------------------------
    # Verify Razorpay signature
    # ------------------------------------------

    Razorpay::Utility.verify_payment_signature(
      razorpay_order_id: order_id,
      razorpay_payment_id: payment_id,
      razorpay_signature: signature
    )

    # ------------------------------------------
    # Update purchase
    # ------------------------------------------

    @purchase.update!(
      razorpay_payment_id: payment_id,
      razorpay_signature: signature,
      payment_status: "paid",
      status: "Active"
    )

    redirect_to test_series_payment_success_path(@purchase),
                notice: "Payment successful. You now have access to this Test Series."

  rescue Razorpay::SignatureVerificationError

    Rails.logger.error(
      "TEST SERIES RAZORPAY SIGNATURE VERIFICATION FAILED"
    )

    @purchase&.update(
      payment_status: "failed",
      status: "Failed"
    )

    redirect_to test_series_payment_failed_path(@purchase),
                alert: "Payment verification failed."

  rescue ActiveRecord::RecordNotFound

    redirect_to test_series_index_path,
                alert: "Purchase not found."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "TEST SERIES PAYMENT ERROR: #{e.message}"
    )

    redirect_to test_series_payment_failed_path(@purchase),
                alert: "Payment was received but could not be recorded."

  rescue StandardError => e

    Rails.logger.error(
      "TEST SERIES PAYMENT ERROR: #{e.class} - #{e.message}"
    )

    redirect_to test_series_payment_failed_path(@purchase),
                alert: "Something went wrong while verifying payment."
  end


  # ==================================================
  # PAYMENT SUCCESS
  # ==================================================

  def success

    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series
  end


  # ==================================================
  # PAYMENT FAILED
  # ==================================================

  def failed

    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series
  end


  private


  def set_test_series
    @test_series = TestSeries.find(params[:test_series_id])
  end

end