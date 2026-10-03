class TestSeriesPurchasesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_test_series, only: [:create]

  def create
    if @test_series.free?
      purchase =
        current_user.test_series_purchases.find_or_initialize_by(
          test_series: @test_series
        )

      purchase.amount = 0
      purchase.original_amount = 0
      purchase.discount_amount = 0
      purchase.final_amount = 0
      purchase.coupon = nil
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

    amount = @test_series.price.to_d

    if amount <= 0
      redirect_to test_series_path(@test_series),
                  alert: "Invalid Test Series price."
      return
    end

    razorpay_order =
      create_razorpay_order(
        amount,
        "test_series_#{@test_series.id}_#{current_user.id}_#{Time.current.to_i}"
      )

    purchase =
      current_user.test_series_purchases.create!(
        test_series: @test_series,
        amount: amount,
        original_amount: amount,
        discount_amount: 0,
        final_amount: amount,
        payment_status: "pending",
        status: "Pending",
        razorpay_order_id: razorpay_order.id
      )

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

  def payment
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_path(@test_series),
                  notice: "You already have access to this Test Series."
      return
    end

    if @purchase.razorpay_order_id.blank?
      redirect_to test_series_path(@test_series),
                  alert: "Payment order was not created."
      return
    end
  end

  def apply_coupon
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_payment_path(@purchase),
                  alert: "Payment is already completed."
      return
    end

    code = params[:coupon_code].to_s.strip.upcase

    if code.blank?
      redirect_to test_series_payment_path(@purchase),
                  alert: "Please enter a coupon code."
      return
    end

    coupon = Coupon.find_by("UPPER(code) = ?", code)

    unless coupon.present?
      redirect_to test_series_payment_path(@purchase),
                  alert: "Invalid coupon code."
      return
    end

    unless coupon.applicable_to?(@test_series)
      redirect_to test_series_payment_path(@purchase),
                  alert: "This coupon is not valid for this Test Series."
      return
    end

    unless coupon.available_for_user?(current_user)
      redirect_to test_series_payment_path(@purchase),
                  alert: "This coupon is not available for you or has already been used."
      return
    end

    @purchase.apply_coupon!(coupon)

    razorpay_order =
      create_razorpay_order(
        @purchase.payable_amount,
        "test_series_#{@test_series.id}_#{current_user.id}_#{Time.current.to_i}"
      )

    @purchase.update!(
      razorpay_order_id: razorpay_order.id,
      payment_status: "pending",
      status: "Pending",
      razorpay_payment_id: nil,
      razorpay_signature: nil
    )

    redirect_to test_series_payment_path(@purchase),
                notice: "Coupon #{coupon.code} applied successfully."

  rescue Razorpay::Error => e
    Rails.logger.error(
      "TEST SERIES COUPON RAZORPAY ERROR: #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: "Coupon was applied, but payment order could not be updated."

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      "TEST SERIES COUPON ERROR: #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: e.record.errors.full_messages.to_sentence

  rescue StandardError => e
    Rails.logger.error(
      "TEST SERIES COUPON ERROR: #{e.class} - #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: "Unable to apply coupon. Please try again."
  end

  def remove_coupon
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_payment_path(@purchase),
                  alert: "Payment is already completed."
      return
    end

    @purchase.remove_coupon!

    razorpay_order =
      create_razorpay_order(
        @purchase.payable_amount,
        "test_series_#{@test_series.id}_#{current_user.id}_#{Time.current.to_i}"
      )

    @purchase.update!(
      razorpay_order_id: razorpay_order.id,
      payment_status: "pending",
      status: "Pending",
      razorpay_payment_id: nil,
      razorpay_signature: nil
    )

    redirect_to test_series_payment_path(@purchase),
                notice: "Coupon removed successfully."

  rescue Razorpay::Error => e
    Rails.logger.error(
      "TEST SERIES REMOVE COUPON RAZORPAY ERROR: #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: "Coupon was removed, but payment order could not be updated."

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      "TEST SERIES REMOVE COUPON ERROR: #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: e.record.errors.full_messages.to_sentence

  rescue StandardError => e
    Rails.logger.error(
      "TEST SERIES REMOVE COUPON ERROR: #{e.class} - #{e.message}"
    )

    redirect_to test_series_payment_path(@purchase),
                alert: "Unable to remove coupon. Please try again."
  end

  def verify
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series

    payment_id = params[:razorpay_payment_id]
    order_id = params[:razorpay_order_id]
    signature = params[:razorpay_signature]

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to test_series_payment_failed_path(@purchase),
                  alert: "Payment verification information is missing."
      return
    end

    unless @purchase.razorpay_order_id == order_id
      redirect_to test_series_payment_failed_path(@purchase),
                  alert: "Invalid payment order."
      return
    end

    if @purchase.payment_status == "paid" &&
       @purchase.status == "Active"

      redirect_to test_series_payment_success_path(@purchase),
                  notice: "Payment has already been verified."
      return
    end

    Razorpay::Utility.verify_payment_signature(
      razorpay_order_id: order_id,
      razorpay_payment_id: payment_id,
      razorpay_signature: signature
    )

    razorpay_payment = Razorpay::Payment.fetch(payment_id)

    unless razorpay_payment.order_id.to_s == order_id.to_s
      raise StandardError, "Razorpay payment order mismatch"
    end

    unless razorpay_payment.status.to_s.downcase == "captured"
      raise StandardError, "Razorpay payment was not captured"
    end

    expected_amount =
      (@purchase.payable_amount.to_d * 100).round

    actual_amount =
      razorpay_payment.amount.to_d

    unless actual_amount == expected_amount
      raise StandardError,
            "Razorpay amount mismatch. Expected #{expected_amount}, received #{actual_amount}"
    end

    TestSeriesPurchase.transaction do
      @purchase.with_lock do
        @purchase.update!(
          amount: @purchase.payable_amount,
          razorpay_payment_id: payment_id,
          razorpay_signature: signature,
          payment_status: "paid",
          status: "Active"
        )

        if @purchase.coupon.present?
          CouponUsage.create!(
            coupon: @purchase.coupon,
            user: @purchase.user,
            purchasable: @purchase,
            discount_amount: @purchase.discount_amount.to_d,
            used_at: Time.current
          )

          @purchase.coupon.increment!(:used_count)
        end
      end
    end

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

    @purchase&.update(
      payment_status: "failed",
      status: "Failed"
    )

    redirect_to test_series_payment_failed_path(@purchase),
                alert: "Something went wrong while verifying payment."
  end

  def success
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series
  end

  def failed
    @purchase =
      current_user.test_series_purchases.find(params[:id])

    @test_series = @purchase.test_series
  end

  private

  def set_test_series
    @test_series = TestSeries.find(params[:test_series_id])
  end

  def create_razorpay_order(amount, receipt)
    amount = amount.to_d

    raise Razorpay::Error, "Invalid payment amount" if amount <= 0

    Razorpay::Order.create(
      amount: (amount * 100).round,
      currency: "INR",
      receipt: receipt
    )
  end
end
