# app/controllers/payments_controller.rb

require "razorpay"

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_enrollment

  # =========================================================
  # PAYMENT PAGE
  # =========================================================

  def show
    @course = @enrollment.course

    unless @course
      redirect_to root_path, alert: "Course not found."
      return
    end

    # -------------------------------------------------------
    # Already paid?
    # -------------------------------------------------------

    @payment = latest_payment

    if @payment&.status.to_s == "paid"
      redirect_to payment_success_path(@enrollment),
                  notice: "This payment has already been completed."
      return
    end

    # -------------------------------------------------------
    # Create / reuse Razorpay order
    # -------------------------------------------------------

    create_razorpay_order

    # -------------------------------------------------------
    # Checkout values
    # -------------------------------------------------------

    @razorpay_key_id =
      ENV.fetch("RAZORPAY_KEY_ID")

    @razorpay_order_id =
      @order_id.to_s

    @razorpay_amount =
      (@payment.amount.to_d * 100).round

    @razorpay_currency =
      "INR"

    @customer_name =
      if current_user.respond_to?(:name)
        current_user.name.to_s
      else
        current_user.email.to_s
      end

    @customer_email =
      current_user.email.to_s

    @customer_phone =
      if current_user.respond_to?(:mobile)
        current_user.mobile.to_s
      elsif current_user.respond_to?(:phone)
        current_user.phone.to_s
      else
        ""
      end

  rescue Razorpay::BadRequestError => e
    log_payment_error("RAZORPAY BAD REQUEST", e)

    redirect_to root_path,
                alert: "Unable to create Razorpay payment order."

  rescue Razorpay::ServerError => e
    log_payment_error("RAZORPAY SERVER ERROR", e)

    redirect_to root_path,
                alert: "Razorpay server error. Please try again."

  rescue StandardError => e
    log_payment_error("PAYMENT SHOW ERROR", e)

    redirect_to root_path,
                alert: "Unable to load payment page."
  end


  # =========================================================
  # CREATE PAYMENT ORDER
  # =========================================================

  def create
    @course = @enrollment.course

    unless @course
      redirect_to root_path,
                  alert: "Course not found."
      return
    end

    create_razorpay_order

    redirect_to payment_path(@enrollment)

  rescue Razorpay::BadRequestError => e
    log_payment_error("RAZORPAY CREATE BAD REQUEST", e)

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment order."

  rescue Razorpay::ServerError => e
    log_payment_error("RAZORPAY CREATE SERVER ERROR", e)

    redirect_to payment_path(@enrollment),
                alert: "Razorpay server error. Please try again."

  rescue StandardError => e
    log_payment_error("PAYMENT CREATE ERROR", e)

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment order."
  end


  # =========================================================
  # VERIFY PAYMENT
  # =========================================================

  def verify
    @course = @enrollment.course

    payment_id =
      params[:razorpay_payment_id].to_s.strip

    checkout_order_id =
      params[:razorpay_order_id].to_s.strip

    signature =
      params[:razorpay_signature].to_s.strip

    # -------------------------------------------------------
    # Validate checkout response
    # -------------------------------------------------------

    if payment_id.blank? ||
       checkout_order_id.blank? ||
       signature.blank?

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification details are missing."
      return
    end

    # -------------------------------------------------------
    # Find our local payment
    # -------------------------------------------------------

    payment =
      @enrollment.payments.find_by(
        razorpay_order_id: checkout_order_id
      )

    unless payment
      Rails.logger.error(
        "PAYMENT NOT FOUND: " \
        "order=#{checkout_order_id}, " \
        "enrollment=#{@enrollment.id}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment record not found."
      return
    end

    # -------------------------------------------------------
    # Prevent duplicate verification
    # -------------------------------------------------------

    if payment.status.to_s == "paid"
      redirect_to payment_success_path(@enrollment),
                  notice: "Payment already verified."
      return
    end

    begin
      # -----------------------------------------------------
      # SERVER-SIDE SIGNATURE VERIFICATION
      # -----------------------------------------------------

      server_order_id =
        payment.razorpay_order_id.to_s

      Razorpay::Utility.verify_payment_signature(
        {
          razorpay_order_id: server_order_id,
          razorpay_payment_id: payment_id,
          razorpay_signature: signature
        },
        ENV.fetch("RAZORPAY_KEY_SECRET")
      )

      Rails.logger.info(
        "RAZORPAY SIGNATURE VERIFIED: " \
        "payment=#{payment_id}, " \
        "order=#{server_order_id}"
      )

      # -----------------------------------------------------
      # FETCH PAYMENT FROM RAZORPAY
      # -----------------------------------------------------

      razorpay_payment =
        Razorpay::Payment.fetch(payment_id)

      razorpay_status =
        razorpay_payment.status.to_s

      Rails.logger.info(
        "RAZORPAY PAYMENT STATUS: " \
        "#{razorpay_status}"
      )

      # -----------------------------------------------------
      # PAYMENT MUST BE CAPTURED
      # -----------------------------------------------------

      unless razorpay_status == "captured"
        Rails.logger.warn(
          "PAYMENT NOT CAPTURED: " \
          "payment=#{payment_id}, " \
          "status=#{razorpay_status}"
        )

        redirect_to payment_failed_path(@enrollment),
                    alert:
                      "Payment is not yet captured. " \
                      "Current status: #{razorpay_status}."
        return
      end

      # -----------------------------------------------------
      # AMOUNT VALIDATION
      # -----------------------------------------------------

      expected_amount =
        (payment.amount.to_d * 100).round

      actual_amount =
        razorpay_payment.amount.to_i

      if actual_amount != expected_amount
        Rails.logger.error(
          "PAYMENT AMOUNT MISMATCH: " \
          "expected=#{expected_amount}, " \
          "actual=#{actual_amount}"
        )

        redirect_to payment_failed_path(@enrollment),
                    alert: "Payment amount verification failed."
        return
      end

      # -----------------------------------------------------
      # UPDATE PAYMENT
      # -----------------------------------------------------

      payment.update!(
        razorpay_payment_id: payment_id,
        razorpay_signature: signature,
        status: "paid"
      )

      # -----------------------------------------------------
      # APPROVE ENROLLMENT
      # -----------------------------------------------------

      @enrollment.update!(
        status: "approved"
      )

      # -----------------------------------------------------
      # UPDATE FEE
      # -----------------------------------------------------

      update_enrollment_fee(payment)

      Rails.logger.info(
        "PAYMENT SUCCESSFULLY VERIFIED: " \
        "payment=#{payment_id}, " \
        "order=#{server_order_id}, " \
        "enrollment=#{@enrollment.id}"
      )

      redirect_to payment_success_path(@enrollment),
                  notice: "Payment successful!"

    rescue Razorpay::Error => e
      log_payment_error("RAZORPAY VERIFICATION ERROR", e)

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification failed."

    rescue ActiveRecord::RecordInvalid => e
      log_payment_error("PAYMENT DATABASE ERROR", e)

      redirect_to payment_failed_path(@enrollment),
                  alert:
                    "Payment was received but could not be recorded."

    rescue StandardError => e
      log_payment_error("PAYMENT VERIFICATION ERROR", e)

      redirect_to payment_failed_path(@enrollment),
                  alert: "Unable to verify payment."
    end
  end


  # =========================================================
  # PAYMENT SUCCESS
  # =========================================================

  def success
    @course = @enrollment.course

    @payment =
      @enrollment.payments
                 .where(status: "paid")
                 .order(created_at: :desc)
                 .first
  end


  # =========================================================
  # PAYMENT FAILED
  # =========================================================

  def failed
    @course = @enrollment.course

    @payment =
      @enrollment.payments
                 .order(created_at: :desc)
                 .first
  end


  private


  # =========================================================
  # SET ENROLLMENT
  # =========================================================

  def set_enrollment
    @enrollment =
      current_user.enrollments.find(params[:id])
  end


  # =========================================================
  # LATEST PAYMENT
  # =========================================================

  def latest_payment
    @enrollment.payments
               .order(created_at: :desc)
               .first
  end


  # =========================================================
  # CREATE / REUSE RAZORPAY ORDER
  # =========================================================

  def create_razorpay_order
    @course ||= @enrollment.course

    raise "Course not found." unless @course

    # -------------------------------------------------------
    # Course fee
    # -------------------------------------------------------

    amount_rupees =
      @course.fee.to_d

    amount_paise =
      (amount_rupees * 100).round

    if amount_paise <= 0
      raise "Course fee must be greater than zero."
    end

    # -------------------------------------------------------
    # Already paid
    # -------------------------------------------------------

    paid_payment =
      @enrollment.payments
                 .where(status: "paid")
                 .order(created_at: :desc)
                 .first

    if paid_payment
      @payment = paid_payment
      @order_id = paid_payment.razorpay_order_id

      return
    end

    # -------------------------------------------------------
    # Existing unpaid payment/order
    # -------------------------------------------------------

    existing_payment =
      @enrollment.payments
                 .where(
                   status: %w[created pending]
                 )
                 .where.not(
                   razorpay_order_id: [nil, ""]
                 )
                 .order(created_at: :desc)
                 .first

    if existing_payment
      @payment = existing_payment
      @order_id = existing_payment.razorpay_order_id

      Rails.logger.info(
        "REUSING RAZORPAY ORDER: #{@order_id}"
      )

      return
    end

    # -------------------------------------------------------
    # Create new Razorpay order
    # -------------------------------------------------------

    receipt =
      "ENR-#{@enrollment.id}-#{Time.current.to_i}"

    Rails.logger.info(
      "CREATING RAZORPAY ORDER: " \
      "enrollment=#{@enrollment.id}, " \
      "amount_paise=#{amount_paise}"
    )

    razorpay_order =
      Razorpay::Order.create(
        amount: amount_paise,
        currency: "INR",
        receipt: receipt,
        notes: {
          enrollment_id: @enrollment.id.to_s,
          user_id: current_user.id.to_s,
          course_id: @course.id.to_s
        }
      )

    # -------------------------------------------------------
    # Save local payment
    # -------------------------------------------------------

    @payment =
      @enrollment.payments.create!(
        amount: amount_rupees,
        status: "created",
        razorpay_order_id: razorpay_order.id
      )

    @order_id =
      razorpay_order.id

    Rails.logger.info(
      "RAZORPAY ORDER CREATED: #{@order_id}"
    )
  end


  # =========================================================
  # UPDATE ENROLLMENT FEE
  # =========================================================

  def update_enrollment_fee(payment)
    return unless @enrollment.respond_to?(:fees)

    fee =
      @enrollment.fees
                 .order(created_at: :desc)
                 .first

    payment_amount =
      payment.amount.to_d

    if fee
      old_paid =
        fee.paid_amount.to_d

      paid_amount =
        old_paid + payment_amount

      total_fee =
        if fee.total_fee.present?
          fee.total_fee.to_d
        else
          @course.fee.to_d
        end

      due_amount =
        [total_fee - paid_amount, 0].max

      fee.update!(
        paid_amount: paid_amount,
        due_amount: due_amount,
        payment_date: Date.current,
        payment_mode: "Razorpay",
        status: due_amount.zero? ? "paid" : "partial"
      )
    else
      total_fee =
        @course.fee.to_d

      paid_amount =
        payment_amount

      due_amount =
        [total_fee - paid_amount, 0].max

      @enrollment.fees.create!(
        total_fee: total_fee,
        paid_amount: paid_amount,
        due_amount: due_amount,
        payment_date: Date.current,
        payment_mode: "Razorpay",
        status: due_amount.zero? ? "paid" : "partial"
      )
    end
  end


  # =========================================================
  # ERROR LOGGER
  # =========================================================

  def log_payment_error(prefix, error)
    Rails.logger.error(
      "#{prefix}: #{error.class} - #{error.message}"
    )

    Rails.logger.error(
      error.backtrace&.first(15)&.join("\n")
    )
  end
end