class PaymentsController < ApplicationController
  before_action :authenticate_user!

  # ==================================================
  # PAYMENT PAGE
  # ==================================================

  def show
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    # Free course
    if @course.free?
      redirect_to course_details_path(@course),
                  alert: "This course is free. No payment is required."
      return
    end

    # Already approved
    if @enrollment.status == "Approved"
      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."
      return
    end

    # Existing unpaid Razorpay payment
    @payment = @enrollment.payments
                          .where(status: ["created", "pending"])
                          .order(created_at: :desc)
                          .first

    # ------------------------------------------
    # Payment/Fee information for payment page
    # ------------------------------------------

    @fee = @enrollment.fee

    if @fee.present?
      @total_fee = @fee.total_fee.to_d
      @discount_amount = @fee.discount_amount.to_d
      @payable_amount = @total_fee - @discount_amount
      @due_amount = @fee.due_amount.to_d
    else
      @total_fee = @course.fee.to_d
      @discount_amount = @course.current_discount_amount.to_d
      @payable_amount = @course.final_fee.to_d
      @due_amount = @payable_amount
    end
  end


  # ==================================================
  # CREATE RAZORPAY ORDER
  # ==================================================

  def create
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    # ------------------------------------------
    # Free course
    # ------------------------------------------

    if @course.free?
      @enrollment.update!(status: "Approved")

      redirect_to learning_course_path(@course),
                  notice: "You have been enrolled in this free course."
      return
    end

    # ------------------------------------------
    # Already approved
    # ------------------------------------------

    if @enrollment.status == "Approved"
      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."
      return
    end

    # ------------------------------------------
    # Existing unpaid Razorpay order
    # ------------------------------------------

    existing_payment = @enrollment.payments
                                   .where(status: ["created", "pending"])
                                   .order(created_at: :desc)
                                   .first

    if existing_payment.present?
      redirect_to payment_path(@enrollment)
      return
    end

    # ==================================================
    # FIND OR CREATE FEE
    # ==================================================

    fee = @enrollment.fee || @enrollment.build_fee

    # Original course fee
    fee.total_fee = @course.fee.to_d

    # ------------------------------------------
    # Apply discount only if Fee doesn't already
    # have one.
    # ------------------------------------------

    if fee.discount_amount.to_d.zero? &&
       @course.has_active_discount?

      discount = @course.active_discount

      fee.discount_amount =
        discount.calculate_discount(@course.fee)

      fee.discount_name =
        discount.name
    end

    fee.paid_amount ||= 0

    # ------------------------------------------
    # Calculate final payable amount
    # ------------------------------------------

    payable_amount =
      fee.total_fee.to_d - fee.discount_amount.to_d

    payable_amount = 0 if payable_amount < 0

    # ------------------------------------------
    # Already fully paid
    # ------------------------------------------

    if fee.paid_amount.to_d >= payable_amount
      fee.save!

      @enrollment.update!(status: "Approved")

      redirect_to learning_course_path(@course),
                  notice: "Your course fee has already been paid."
      return
    end

    # Save Fee before creating Razorpay order
    fee.save!

    # ------------------------------------------
    # Razorpay amount is in paise
    # ------------------------------------------

    amount = (payable_amount * 100).to_i

    if amount <= 0
      redirect_to course_details_path(@course),
                  alert: "Invalid course fee."
      return
    end

    # ------------------------------------------
    # Create Razorpay Order
    # ------------------------------------------

    razorpay_order = Razorpay::Order.create(
      amount: amount,
      currency: "INR",
      receipt: "enrollment_#{@enrollment.id}_#{Time.current.to_i}"
    )

    # ------------------------------------------
    # Create Payment record
    #
    # Store amount in RUPEES in our database.
    # Razorpay receives PAISE.
    # ------------------------------------------

    @enrollment.payments.create!(
      amount: payable_amount,
      razorpay_order_id: razorpay_order.id,
      status: "created"
    )

    redirect_to payment_path(@enrollment)

  rescue Razorpay::Error => e

    Rails.logger.error(
      "RAZORPAY ORDER ERROR: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment. Please try again."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "PAYMENT/FEE RECORD ERROR: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment record."
  end


  # ==================================================
  # VERIFY RAZORPAY PAYMENT
  # ==================================================

  def verify
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    payment_id = params[:razorpay_payment_id]
    order_id = params[:razorpay_order_id]
    signature = params[:razorpay_signature]

    # ------------------------------------------
    # Validate Razorpay response
    # ------------------------------------------

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification information is missing."
      return
    end

    # ------------------------------------------
    # Find Payment
    # ------------------------------------------

    @payment = @enrollment.payments.find_by(
      razorpay_order_id: order_id
    )

    unless @payment
      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment record not found."
      return
    end

    # ------------------------------------------
    # Prevent duplicate verification
    # ------------------------------------------

    if @payment.status == "paid"
      redirect_to payment_success_path(@enrollment),
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

    # ==================================================
    # DATABASE TRANSACTION
    # ==================================================

    ActiveRecord::Base.transaction do

      # ------------------------------------------
      # Mark Payment as Paid
      # ------------------------------------------

      @payment.update!(
        razorpay_payment_id: payment_id,
        razorpay_signature: signature,
        status: "paid"
      )

      # ==================================================
      # FIND OR CREATE SINGLE FEE
      # ==================================================

      fee = Fee.find_or_initialize_by(
        enrollment_id: @enrollment.id
      )

      # ------------------------------------------
      # Original course fee
      # ------------------------------------------

      fee.total_fee = @course.fee.to_d

      # ------------------------------------------
      # Apply active discount only when Fee
      # doesn't already have a discount.
      # ------------------------------------------

      if fee.discount_amount.to_d.zero? &&
         @course.has_active_discount?

        discount = @course.active_discount

        fee.discount_amount =
          discount.calculate_discount(@course.fee)

        fee.discount_name =
          discount.name
      end

      fee.paid_amount ||= 0

      # ------------------------------------------
      # Online payment amount
      #
      # Payment.amount is stored in RUPEES.
      # ------------------------------------------

      online_amount = @payment.amount.to_d

      # ------------------------------------------
      # Add this payment exactly once
      # ------------------------------------------

      already_recorded =
        fee.payment_mode == "Razorpay" &&
        fee.receipt_no == payment_id

      unless already_recorded
        fee.paid_amount =
          fee.paid_amount.to_d + online_amount
      end

      # ------------------------------------------
      # Payment information
      # ------------------------------------------

      fee.payment_date = Date.current
      fee.payment_mode = "Razorpay"
      fee.receipt_no = payment_id

      # ------------------------------------------
      # Save Fee
      #
      # Fee callbacks calculate:
      # - due_amount
      # - status
      # ------------------------------------------

      fee.save!

      # ------------------------------------------
      # Approve enrollment
      # ------------------------------------------

      @enrollment.update!(
        status: "Approved"
      )
    end

    # ------------------------------------------
    # Success
    # ------------------------------------------

    redirect_to payment_success_path(@enrollment),
                notice: "Payment successful. You now have access to the course."

  rescue Razorpay::SignatureVerificationError

    Rails.logger.error(
      "RAZORPAY SIGNATURE VERIFICATION FAILED"
    )

    @payment&.update(status: "failed")

    redirect_to payment_failed_path(@enrollment),
                alert: "Payment verification failed."

  rescue ActiveRecord::RecordNotFound

    redirect_to homepage_path,
                alert: "Enrollment not found."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "PAYMENT/FEE ERROR: #{e.message}"
    )

    redirect_to payment_failed_path(@enrollment),
                alert: "Payment was received but could not be recorded. Please contact administration."

  rescue StandardError => e

    Rails.logger.error(
      "RAZORPAY VERIFY ERROR: #{e.class} - #{e.message}"
    )

    redirect_to payment_failed_path(@enrollment),
                alert: "Something went wrong while verifying payment."
  end


  # ==================================================
  # PAYMENT SUCCESS
  # ==================================================

  def success
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    @fee = @enrollment.fee

    @payment = @enrollment.payments
                          .where(status: "paid")
                          .order(created_at: :desc)
                          .first
  end


  # ==================================================
  # PAYMENT FAILED
  # ==================================================

  def failed
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course
  end
end
