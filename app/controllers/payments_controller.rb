class PaymentsController < ApplicationController
  before_action :authenticate_user!

  # ==================================================
  # PAYMENT PAGE
  # ==================================================

  def show
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    # Free course should never reach payment
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

    # Find existing unpaid payment
    @payment = @enrollment.payments
                          .where(status: ["created", "pending"])
                          .order(created_at: :desc)
                          .first
  end


  # ==================================================
  # CREATE RAZORPAY ORDER
  # ==================================================

  def create
    @enrollment = current_user.enrollments.find(params[:id])
    @course = @enrollment.course

    # ------------------------------------------
    # Free course protection
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
    # Reuse existing unpaid payment
    # ------------------------------------------

    existing_payment = @enrollment.payments
                                   .where(status: ["created", "pending"])
                                   .order(created_at: :desc)
                                   .first

    if existing_payment.present?
      redirect_to payment_path(@enrollment)
      return
    end

    # ------------------------------------------
    # Amount
    # ------------------------------------------

    amount = (@course.fee.to_d * 100).to_i

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
    # Save Payment
    # ------------------------------------------

    @enrollment.payments.create!(
      amount: amount,
      razorpay_order_id: razorpay_order.id,
      status: "created"
    )

    # ------------------------------------------
    # Open Payment Page
    # ------------------------------------------

    redirect_to payment_path(@enrollment)

  rescue Razorpay::Error => e

    Rails.logger.error(
      "RAZORPAY ORDER ERROR: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment. Please try again."

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "PAYMENT RECORD ERROR: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to create payment record."
  end


  # ==================================================
  # VERIFY RAZORPAY PAYMENT
  # ==================================================

  def verify

    @enrollment =
      current_user.enrollments.find(params[:id])

    @course = @enrollment.course

    payment_id = params[:razorpay_payment_id]
    order_id = params[:razorpay_order_id]
    signature = params[:razorpay_signature]

    # ------------------------------------------
    # Validate response
    # ------------------------------------------

    if payment_id.blank? ||
       order_id.blank? ||
       signature.blank?

      redirect_to payment_failed_path(@enrollment),
                  alert: "Payment verification information is missing."

      return
    end

    # ------------------------------------------
    # Find payment
    # ------------------------------------------

    @payment =
      @enrollment.payments.find_by(
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
      {
        razorpay_order_id: order_id,
        razorpay_payment_id: payment_id,
        razorpay_signature: signature
      }
    )

    # ------------------------------------------
    # Save payment
    # ------------------------------------------

    @payment.update!(
      razorpay_payment_id: payment_id,
      razorpay_signature: signature,
      status: "paid"
    )

    # ------------------------------------------
    # Approve enrollment
    # ------------------------------------------

    @enrollment.update!(
      status: "Approved"
    )

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

    @enrollment =
      current_user.enrollments.find(params[:id])

    @course = @enrollment.course

  end


  # ==================================================
  # PAYMENT FAILED
  # ==================================================

  def failed

    @enrollment =
      current_user.enrollments.find(params[:id])

    @course = @enrollment.course

  end

end