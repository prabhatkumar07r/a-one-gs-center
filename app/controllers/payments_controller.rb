class PaymentsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_enrollment


  # =========================================================
  # SHOW PAYMENT PAGE
  # =========================================================

  def show

    @course = @enrollment.course

    # -------------------------------------------------------
    # Already approved
    # -------------------------------------------------------

    if @enrollment.status.to_s.downcase == "approved"

      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."

      return
    end


    # -------------------------------------------------------
    # Find latest unpaid Razorpay order
    # -------------------------------------------------------

    @payment = @enrollment.payments
                          .where(status: "created")
                          .where.not(razorpay_order_id: [nil, ""])
                          .order(created_at: :desc)
                          .first


    # -------------------------------------------------------
    # Razorpay order ID
    # -------------------------------------------------------

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

      Razorpay.setup(
        ENV.fetch("RAZORPAY_KEY_ID"),
        ENV.fetch("RAZORPAY_KEY_SECRET")
      )


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
      # Check existing unpaid order
      # -----------------------------------------------------

      @payment = @enrollment.payments
                            .where(status: "created")
                            .where.not(razorpay_order_id: [nil, ""])
                            .order(created_at: :desc)
                            .first


      if @payment.present?

        Rails.logger.info(
          "Using existing Razorpay order: " \
          "#{@payment.razorpay_order_id}"
        )


        redirect_to payment_path(@enrollment),
                    notice: "Payment order is ready."

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
            "enrollment_#{@enrollment.id}",

          payment_capture: 1

        )


      Rails.logger.info(
        "========================================"
      )

      Rails.logger.info(
        "Razorpay Order Created"
      )

      Rails.logger.info(
        "Enrollment: #{@enrollment.id}"
      )

      Rails.logger.info(
        "Order ID: #{razorpay_order.id}"
      )

      Rails.logger.info(
        "Amount: #{amount_paise} paise"
      )

      Rails.logger.info(
        "========================================"
      )


      # -----------------------------------------------------
      # Save local payment
      # -----------------------------------------------------

      @payment =
        @enrollment.payments.create!(

          amount: amount_rupees,

          razorpay_order_id:
            razorpay_order.id,

          status: "created"

        )


      # -----------------------------------------------------
      # Redirect to payment page
      # -----------------------------------------------------

      redirect_to payment_path(@enrollment),
                  notice: "Secure payment is ready."


    rescue KeyError => e

      Rails.logger.error(
        "Razorpay ENV Error: #{e.message}"
      )


      redirect_to payment_path(@enrollment),
                  alert:
                    "Razorpay configuration is missing."


    rescue Razorpay::Error => e

      Rails.logger.error(
        "Razorpay API Error: " \
        "#{e.class} - #{e.message}"
      )


      redirect_to payment_path(@enrollment),
                  alert:
                    "Unable to create Razorpay payment."


    rescue ActiveRecord::RecordInvalid => e

      Rails.logger.error(
        "Payment Record Error: #{e.message}"
      )


      redirect_to payment_path(@enrollment),
                  alert:
                    "Unable to save payment information."


    rescue StandardError => e

      Rails.logger.error(
        "Razorpay Create Error: " \
        "#{e.class} - #{e.message}"
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
    # Get payment from submitted order ID
    # -------------------------------------------------------

    razorpay_payment_id =
      params[:razorpay_payment_id].to_s.strip

    razorpay_order_id =
      params[:razorpay_order_id].to_s.strip

    razorpay_signature =
      params[:razorpay_signature].to_s.strip


    # -------------------------------------------------------
    # Validate parameters
    # -------------------------------------------------------

    if razorpay_payment_id.blank? ||
       razorpay_order_id.blank? ||
       razorpay_signature.blank?

      Rails.logger.error(
        "Razorpay verification parameters missing."
      )


      redirect_to payment_failed_path(@enrollment),
                  alert:
                    "Payment verification data is incomplete."

      return
    end


    # -------------------------------------------------------
    # Find payment belonging to this enrollment/order
    # -------------------------------------------------------

    @payment =
      @enrollment.payments
                 .where(status: "created")
                 .find_by(
                   razorpay_order_id:
                     razorpay_order_id
                 )


    unless @payment

      Rails.logger.error(
        "Payment/order mismatch."
      )

      Rails.logger.error(
        "Enrollment: #{@enrollment.id}"
      )

      Rails.logger.error(
        "Received Order: #{razorpay_order_id}"
      )


      redirect_to payment_failed_path(@enrollment),
                  alert:
                    "Payment order verification failed."

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
        "Razorpay signature verified."
      )


      # -----------------------------------------------------
      # Fetch payment from Razorpay
      #
      # This is an additional server-side check.
      # -----------------------------------------------------

      razorpay_payment =
        Razorpay::Payment.fetch(
          razorpay_payment_id
        )


      # -----------------------------------------------------
      # Verify payment belongs to our order
      # -----------------------------------------------------

      fetched_order_id =
        razorpay_payment.order_id.to_s


      unless fetched_order_id == razorpay_order_id

        Rails.logger.error(
          "Razorpay payment/order mismatch."
        )

        Rails.logger.error(
          "Expected: #{razorpay_order_id}"
        )

        Rails.logger.error(
          "Received: #{fetched_order_id}"
        )


        raise(
          "Razorpay payment does not belong to this order."
        )

      end


      # -----------------------------------------------------
      # Verify amount
      # -----------------------------------------------------

      expected_amount =
        (@payment.amount.to_d * 100).to_i


      received_amount =
        razorpay_payment.amount.to_i


      unless received_amount == expected_amount

        Rails.logger.error(
          "Razorpay amount mismatch."
        )

        Rails.logger.error(
          "Expected: #{expected_amount}"
        )

        Rails.logger.error(
          "Received: #{received_amount}"
        )


        raise(
          "Razorpay payment amount mismatch."
        )

      end


      # -----------------------------------------------------
      # Verify payment status
      # -----------------------------------------------------

      razorpay_status =
        razorpay_payment.status.to_s.downcase


      unless razorpay_status == "captured"

        Rails.logger.error(
          "Razorpay payment not captured."
        )

        Rails.logger.error(
          "Status: #{razorpay_status}"
        )


        redirect_to payment_failed_path(@enrollment),
                    alert:
                      "Payment was not successfully captured."

        return
      end


      # -----------------------------------------------------
      # Save payment
      # -----------------------------------------------------

      ActiveRecord::Base.transaction do

        @payment.update!(

          razorpay_payment_id:
            razorpay_payment_id,

          razorpay_signature:
            razorpay_signature,

          status:
            "paid"

        )


        # ---------------------------------------------------
        # Approve enrollment
        # ---------------------------------------------------

        @enrollment.update!(

          status:
            "Approved"

        )

      end


      Rails.logger.info(
        "========================================"
      )

      Rails.logger.info(
        "PAYMENT SUCCESSFUL"
      )

      Rails.logger.info(
        "Enrollment: #{@enrollment.id}"
      )

      Rails.logger.info(
        "Order: #{razorpay_order_id}"
      )

      Rails.logger.info(
        "Payment: #{razorpay_payment_id}"
      )

      Rails.logger.info(
        "Enrollment Approved"
      )

      Rails.logger.info(
        "========================================"
      )


      # -----------------------------------------------------
      # Send student to learning page
      # -----------------------------------------------------

      redirect_to learning_course_path(@course),
                  notice:
                    "Payment successful. You now have access to the course."


    rescue Razorpay::SignatureVerificationError => e

      Rails.logger.error(
        "Razorpay Signature Verification Failed: " \
        "#{e.message}"
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
        "Razorpay Verification Error: " \
        "#{e.class} - #{e.message}"
      )

      Rails.logger.error(
        e.backtrace.join("\n")
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