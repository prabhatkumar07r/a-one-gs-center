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

    @payment =
      @enrollment.payments
                 .order(created_at: :desc)
                 .first

    # Reuse existing Razorpay order
    @order_id =
      @payment&.razorpay_order_id.presence

    # Create order if none exists
    unless @order_id
      create_razorpay_order
    end

  rescue Razorpay::Errors::ServerError,
         Razorpay::Errors::BadRequestError => e

    Rails.logger.error(
      "Razorpay order creation failed: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment order. Please try again."

  rescue StandardError => e

    Rails.logger.error(
      "Payment page error: #{e.class} - #{e.message}"
    )

    redirect_to root_path,
                alert: "Unable to load payment page."
  end


  # =========================================================
  # CREATE PAYMENT / RAZORPAY ORDER
  # =========================================================
  def create
    @course = @enrollment.course

    unless @course
      redirect_to root_path, alert: "Course not found."
      return
    end

    create_razorpay_order

    redirect_to payment_path(@enrollment)

  rescue Razorpay::Errors::ServerError,
         Razorpay::Errors::BadRequestError => e

    Rails.logger.error(
      "Razorpay order creation failed: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment order. Please try again."

  rescue StandardError => e

    Rails.logger.error(
      "Payment creation error: #{e.class} - #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Something went wrong while creating payment."
  end


  # =========================================================
  # VERIFY RAZORPAY PAYMENT
  #
  # No fetch()
  # No AJAX verification
  #
  # Razorpay Checkout sends:
  #   razorpay_payment_id
  #   razorpay_order_id
  #   razorpay_signature
  #
  # Rails verifies the signature server-side.
  # =========================================================
  def verify
    @course = @enrollment.course

    payment_id = params[:razorpay_payment_id]
    signature  = params[:razorpay_signature]
    order_id   = params[:razorpay_order_id]

    # -------------------------------------------------------
    # BASIC VALIDATION
    # -------------------------------------------------------

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification details are missing."
      return
    end


    # -------------------------------------------------------
    # FIND OUR PAYMENT RECORD
    # -------------------------------------------------------

    payment =
      @enrollment.payments.find_by(
        razorpay_order_id: order_id
      )

    unless payment

      Rails.logger.error(
        "Payment record not found for Razorpay order #{order_id}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment record not found."
      return
    end


    begin

      # -----------------------------------------------------
      # VERIFY RAZORPAY SIGNATURE
      # -----------------------------------------------------

      Razorpay::Utility.verify_payment_signature(
        {
          razorpay_order_id: payment.razorpay_order_id,
          razorpay_payment_id: payment_id,
          razorpay_signature: signature
        },
        ENV.fetch("RAZORPAY_KEY_SECRET")
      )


      # -----------------------------------------------------
      # PREVENT DUPLICATE PAYMENT PROCESSING
      # -----------------------------------------------------

      if payment.status.to_s == "paid"

        redirect_to payment_success_path(@enrollment),
                    notice: "Payment already verified."

        return
      end


      # -----------------------------------------------------
      # SAVE PAYMENT
      #
      # Your payments table does NOT contain paid_at.
      # Therefore paid_at is intentionally NOT saved.
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
      # UPDATE / CREATE FEE RECORD
      # -----------------------------------------------------

      if @enrollment.respond_to?(:fees)

        fee =
          @enrollment.fees
                     .order(created_at: :desc)
                     .first

        if fee

          paid_amount =
            fee.paid_amount.to_d +
            payment.amount.to_d

          total_fee =
            fee.total_fee.presence ||
            @course.fee.to_d

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
            payment.amount.to_d

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


      # -----------------------------------------------------
      # SUCCESS
      # -----------------------------------------------------

      redirect_to payment_success_path(@enrollment),
                  notice: "Payment successful!"


    rescue Razorpay::Errors::SignatureVerificationError => e

      Rails.logger.error(
        "Razorpay signature verification failed: #{e.message}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification failed."


    rescue ActiveRecord::RecordInvalid => e

      Rails.logger.error(
        "Payment database error: #{e.message}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment was received but could not be recorded."


    rescue StandardError => e

      Rails.logger.error(
        "Payment verification error: #{e.class} - #{e.message}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Unable to verify payment."

    end
  end


  # =========================================================
  # PAYMENT SUCCESS PAGE
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
  # PAYMENT FAILED PAGE
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
  # CREATE RAZORPAY ORDER
  # =========================================================
  def create_razorpay_order

    amount =
      (@course.fee.to_d * 100).round


    if amount <= 0
      raise "Course fee must be greater than zero."
    end


    # =====================================================
    # REUSE EXISTING UNPAID ORDER
    # =====================================================

    existing_payment =
      @enrollment.payments
                 .where(status: ["created", "pending"])
                 .where.not(razorpay_order_id: nil)
                 .order(created_at: :desc)
                 .first


    if existing_payment

      @payment =
        existing_payment

      @order_id =
        existing_payment.razorpay_order_id

      return
    end


    # =====================================================
    # CREATE RAZORPAY ORDER
    # =====================================================

    razorpay_order =
      Razorpay::Order.create(
        amount: amount,
        currency: "INR",
        receipt: "ENR-#{@enrollment.id}-#{Time.current.to_i}",
        notes: {
          enrollment_id: @enrollment.id,
          user_id: current_user.id,
          course_id: @course.id
        }
      )


    # =====================================================
    # SAVE PAYMENT
    # =====================================================

    @payment =
      @enrollment.payments.create!(
        amount: @course.fee,
        status: "created",
        razorpay_order_id: razorpay_order.id
      )


    @order_id =
      razorpay_order.id
  end
end