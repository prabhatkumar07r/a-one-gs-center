class PaymentsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_enrollment

  # =========================================================
  # SHOW PAYMENT PAGE
  # =========================================================

  def show
    @course = @enrollment.course

    @payment = @enrollment.payments
                          .where(status: "created")
                          .order(created_at: :desc)
                          .first

    @order_id = @payment&.razorpay_order_id
  end


  # =========================================================
  # CREATE RAZORPAY ORDER
  # =========================================================

  def create
    @course = @enrollment.course

    # -------------------------------------------------------
    # Already approved?
    # -------------------------------------------------------

    if @enrollment.status == "Approved"

      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."

      return
    end


    begin

      # -----------------------------------------------------
      # Razorpay configuration
      # -----------------------------------------------------

      Razorpay.setup(
        ENV.fetch("RAZORPAY_KEY_ID"),
        ENV.fetch("RAZORPAY_KEY_SECRET")
      )


      # -----------------------------------------------------
      # Check existing unpaid order
      # -----------------------------------------------------

      @payment = @enrollment.payments
                            .where(status: "created")
                            .order(created_at: :desc)
                            .first

      if @payment.present? &&
         @payment.razorpay_order_id.present?

        Rails.logger.info(
          "Existing Razorpay Order: #{@payment.razorpay_order_id}"
        )

        redirect_to payment_path(@enrollment),
                    notice: "Payment order is ready."

        return
      end


      # -----------------------------------------------------
      # Amount in paise
      # -----------------------------------------------------

      amount = (@course.fee.to_f * 100).to_i


      # -----------------------------------------------------
      # Validate amount
      # -----------------------------------------------------

      if amount <= 0

        redirect_to payment_path(@enrollment),
                    alert: "Invalid course fee."

        return
      end


      # -----------------------------------------------------
      # Create Razorpay order
      # -----------------------------------------------------

      razorpay_order = Razorpay::Order.create(

        amount: amount,

        currency: "INR",

        receipt: "enrollment_#{@enrollment.id}",

        payment_capture: 1

      )


      Rails.logger.info(
        "Razorpay Order Created: #{razorpay_order.id}"
      )


      # -----------------------------------------------------
      # Save payment locally
      # -----------------------------------------------------

      @payment = @enrollment.payments.create!(

        amount: @course.fee,

        razorpay_order_id: razorpay_order.id,

        status: "created"

      )


      # -----------------------------------------------------
      # Redirect to payment page
      # -----------------------------------------------------

      redirect_to payment_path(@enrollment),
                  notice: "Payment order created successfully."


    rescue KeyError => e

      Rails.logger.error(
        "Razorpay ENV Error: #{e.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert: "Razorpay configuration is missing."


    rescue Razorpay::Error => e

      Rails.logger.error(
        "Razorpay Error: #{e.class} - #{e.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert: "Unable to create Razorpay payment."


    rescue StandardError => e

      Rails.logger.error(
        "#{e.class}: #{e.message}"
      )

      Rails.logger.error(
        e.backtrace.join("\n")
      )

      redirect_to payment_path(@enrollment),
                  alert: "Something went wrong while creating payment."

    end
  end


  # =========================================================
  # VERIFY RAZORPAY PAYMENT
  # =========================================================

  def verify_payment

    @course = @enrollment.course


    # -------------------------------------------------------
    # Get latest created payment
    # -------------------------------------------------------

    @payment = @enrollment.payments
                          .where(status: "created")
                          .order(created_at: :desc)
                          .first


    unless @payment

      redirect_to payment_path(@enrollment),
                  alert: "Payment record not found."

      return
    end


    # -------------------------------------------------------
    # Get Razorpay response
    # -------------------------------------------------------

    razorpay_payment_id =
      params[:razorpay_payment_id]

    razorpay_order_id =
      params[:razorpay_order_id]

    razorpay_signature =
      params[:razorpay_signature]


    # -------------------------------------------------------
    # Validate parameters
    # -------------------------------------------------------

    if razorpay_payment_id.blank? ||
       razorpay_order_id.blank? ||
       razorpay_signature.blank?

      Rails.logger.error(
        "Razorpay verification parameters are missing."
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification data is incomplete."

      return
    end


    # -------------------------------------------------------
    # Make sure order belongs to this payment
    # -------------------------------------------------------

    unless @payment.razorpay_order_id == razorpay_order_id

      Rails.logger.error(
        "Razorpay order mismatch. " \
        "Expected: #{@payment.razorpay_order_id}, " \
        "Received: #{razorpay_order_id}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment order verification failed."

      return
    end


    begin

      # -----------------------------------------------------
      # Verify Razorpay signature
      # -----------------------------------------------------

      Razorpay::Utility.verify_payment_signature(

        {
          "razorpay_order_id" =>
            razorpay_order_id,

          "razorpay_payment_id" =>
            razorpay_payment_id
        },

        razorpay_signature

      )


      Rails.logger.info(
        "Razorpay Payment Verified: #{razorpay_payment_id}"
      )


      # -----------------------------------------------------
      # Update payment
      # -----------------------------------------------------

      @payment.update!(

        razorpay_payment_id:
          razorpay_payment_id,

        razorpay_signature:
          razorpay_signature,

        status:
          "paid"

      )


      # -----------------------------------------------------
      # Approve enrollment
      # -----------------------------------------------------

      @enrollment.update!(
        status: "Approved"
      )


      Rails.logger.info(
        "Enrollment #{@enrollment.id} approved successfully."
      )


      # -----------------------------------------------------
      # Redirect to learning
      # -----------------------------------------------------

      redirect_to learning_course_path(@course),
                  notice: "Payment successful. You now have access to the course."


    rescue Razorpay::SignatureVerificationError => e

      Rails.logger.error(
        "Razorpay Signature Verification Failed: #{e.message}"
      )


      @payment.update(

        razorpay_payment_id:
          razorpay_payment_id,

        razorpay_signature:
          razorpay_signature,

        status:
          "failed"

      )


      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification failed."


    rescue StandardError => e

      Rails.logger.error(
        "Razorpay Verification Error: " \
        "#{e.class} - #{e.message}"
      )

      Rails.logger.error(
        e.backtrace.join("\n")
      )


      redirect_to payment_failed_path(@enrollment),
                  alert: "Unable to verify your payment."

    end

  end


  # =========================================================
  # PAYMENT FAILED
  # =========================================================

  def payment_failed

    @course = @enrollment.course

    @payment = @enrollment.payments
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

end