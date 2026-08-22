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
    # Already approved
    # -------------------------------------------------------

    if @enrollment.status.to_s.downcase == "approved"

      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."

      return
    end


    begin

      # -----------------------------------------------------
      # Razorpay configuration
      # -----------------------------------------------------

      razorpay_key_id =
        ENV.fetch("RAZORPAY_KEY_ID")

      razorpay_key_secret =
        ENV.fetch("RAZORPAY_KEY_SECRET")


      if razorpay_key_id.blank? ||
         razorpay_key_secret.blank?

        raise KeyError,
              "RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET is missing"
      end


      Razorpay.setup(
        razorpay_key_id,
        razorpay_key_secret
      )


      # -----------------------------------------------------
      # Check existing unpaid order
      # -----------------------------------------------------

      @payment = @enrollment.payments
                            .where(status: "created")
                            .where.not(razorpay_order_id: [nil, ""])
                            .order(created_at: :desc)
                            .first


      if @payment.present?

        Rails.logger.info(
          "Using existing Razorpay order: #{@payment.razorpay_order_id}"
        )

        redirect_to payment_path(@enrollment),
                    notice: "Payment order is ready."

        return
      end


      # -----------------------------------------------------
      # Course amount
      # -----------------------------------------------------

      amount_rupees =
        @course.fee.to_d


      amount_paise =
        (amount_rupees * 100).to_i


      # -----------------------------------------------------
      # Validate amount
      # -----------------------------------------------------

      if amount_paise <= 0

        redirect_to payment_path(@enrollment),
                    alert: "Invalid course fee."

        return
      end


      # -----------------------------------------------------
      # Create Razorpay order
      # -----------------------------------------------------

      razorpay_order =
        Razorpay::Order.create(

          amount: amount_paise,

          currency: "INR",

          receipt:
            "enrollment_#{@enrollment.id}_#{Time.current.to_i}",

          payment_capture: 1

        )


      Rails.logger.info(
        "================================================="
      )

      Rails.logger.info(
        "Razorpay Order Created"
      )

      Rails.logger.info(
        "Order ID: #{razorpay_order.id}"
      )

      Rails.logger.info(
        "Amount: #{amount_paise}"
      )

      Rails.logger.info(
        "Currency: INR"
      )

      Rails.logger.info(
        "Enrollment: #{@enrollment.id}"
      )

      Rails.logger.info(
        "================================================="
      )


      # -----------------------------------------------------
      # Save local payment
      # -----------------------------------------------------

      @payment =
        @enrollment.payments.create!(

          amount: amount_rupees,

          razorpay_order_id:
            razorpay_order.id,

          status:
            "created"

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
                  alert:
                    "Razorpay configuration is missing."


    rescue Razorpay::Error => e

      Rails.logger.error(
        "Razorpay API Error: #{e.class} - #{e.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert:
                    "Unable to create Razorpay payment."


    rescue ActiveRecord::RecordInvalid => e

      Rails.logger.error(
        "Payment database error: #{e.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert:
                    "Unable to save payment information."


    rescue StandardError => e

      Rails.logger.error(
        "Payment creation error: #{e.class} - #{e.message}"
      )

      Rails.logger.error(
        e.backtrace.join("\n")
      )

      redirect_to payment_path(@enrollment),
                  alert:
                    "Something went wrong while creating payment."

    end

  end


  # =========================================================
  # VERIFY RAZORPAY PAYMENT
  # =========================================================

  def verify_payment

    @course =
      @enrollment.course


    # -------------------------------------------------------
    # Get payment by Razorpay order ID
    # -------------------------------------------------------

    razorpay_order_id =
      params[:razorpay_order_id].to_s.strip


    @payment =
      @enrollment.payments
                 .where(
                   razorpay_order_id:
                     razorpay_order_id
                 )
                 .where(
                   status: "created"
                 )
                 .order(
                   created_at: :desc
                 )
                 .first


    # -------------------------------------------------------
    # Payment record not found
    # -------------------------------------------------------

    unless @payment

      Rails.logger.error(
        "Payment record not found for order: #{razorpay_order_id}"
      )

      redirect_to payment_failed_path(@enrollment),
                  alert:
                    "Payment record not found."

      return
    end


    # -------------------------------------------------------
    # Get Razorpay response
    # -------------------------------------------------------

    razorpay_payment_id =
      params[:razorpay_payment_id].to_s.strip


    razorpay_signature =
      params[:razorpay_signature].to_s.strip


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
                  alert:
                    "Payment verification data is incomplete."

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
        "Razorpay signature verified successfully."
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
        "Enrollment #{@enrollment.id} approved."
      )


      # -----------------------------------------------------
      # Redirect to learning
      # -----------------------------------------------------

      redirect_to learning_course_path(@course),
                  notice:
                    "Payment successful. You now have access to the course."


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
                  alert:
                    "Payment verification failed."


    rescue StandardError => e

      Rails.logger.error(
        "Razorpay Verification Error: #{e.class} - #{e.message}"
      )

      Rails.logger.error(
        e.backtrace.join("\n")
      )


      redirect_to payment_failed_path(@enrollment),
                  alert:
                    "Unable to verify your payment."

    end

  end


  # =========================================================
  # PAYMENT FAILED
  # =========================================================

  def payment_failed

    @course =
      @enrollment.course


    @payment =
      @enrollment.payments
                 .order(
                   created_at: :desc
                 )
                 .first

  end


  private


  # =========================================================
  # SET ENROLLMENT
  # =========================================================

  def set_enrollment

    @enrollment =
      current_user.enrollments.find(
        params[:id]
      )

  end

end