class PaymentsController < ApplicationController
  before_action :authenticate_user!

  # ==================================================
  # PAYMENT PAGE
  # ==================================================

# ==================================================
# PAYMENT PAGE
# ==================================================

def show
  @enrollment =
    current_user.enrollments.find(params[:id])

  @course =
    @enrollment.course

  # ------------------------------------------
  # Free course
  # ------------------------------------------

  if @course.free?
    redirect_to course_details_path(@course),
                alert: "This course is free. No payment is required."
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
  # Calculate current payable amount FIRST
  # ------------------------------------------

  @total_fee =
    @enrollment.course_price

  @course_discount_amount =
    @enrollment.course_discount_amount

  @coupon_discount_amount =
    if @enrollment.coupon.present?
      @enrollment.discount_amount.to_d
    else
      0.to_d
    end

  @payable_amount =
    @enrollment.payable_amount.to_d

  @due_amount =
    @payable_amount

  # ------------------------------------------
  # Find existing unpaid payment
  # ------------------------------------------

  @payment =
    @enrollment.payments
               .where(status: ["created", "pending"])
               .order(created_at: :desc)
               .first

  # ------------------------------------------
  # IMPORTANT:
  #
  # Never reuse an old Razorpay order when
  # its amount is different from the current
  # payable amount.
  # ------------------------------------------

  if @payment.present? &&
     @payment.amount.to_d != @payable_amount

    Rails.logger.info(
      "PAYMENT AMOUNT MISMATCH: " \
      "Payment ##{@payment.id} has ₹#{@payment.amount}, " \
      "but current payable amount is ₹#{@payable_amount}. " \
      "Marking old payment as cancelled."
    )

    @payment.update!(
      status: "cancelled"
    )

    @payment = nil
  end
end

 # ==================================================
# CREATE RAZORPAY ORDER
# ==================================================

def create
  @enrollment =
    current_user.enrollments.find(params[:id])

  @course =
    @enrollment.course

  # ------------------------------------------
  # Free course
  # ------------------------------------------

  if @course.free?
    @enrollment.update!(
      status: "Approved"
    )

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


  # ==================================================
  # CURRENT PAYABLE AMOUNT
  # ==================================================

  payable_amount =
    @enrollment.payable_amount.to_d


  # ------------------------------------------
  # Validate payable amount
  # ------------------------------------------

  if payable_amount <= 0

    redirect_to course_details_path(@course),
                alert: "Invalid course fee."
    return
  end


  # ==================================================
  # EXISTING UNPAID RAZORPAY ORDER
  # ==================================================

  existing_payment =
    @enrollment.payments
               .where(status: ["created", "pending"])
               .order(created_at: :desc)
               .first


  if existing_payment.present?

    # ------------------------------------------
    # SAME AMOUNT
    #
    # Safe to reuse existing Razorpay order.
    # ------------------------------------------

    if existing_payment.amount.to_d == payable_amount

      redirect_to payment_path(@enrollment)
      return

    end


    # ------------------------------------------
    # DIFFERENT AMOUNT
    #
    # Existing Razorpay order is stale.
    # Do NOT reuse it.
    # ------------------------------------------

    Rails.logger.info(
      "PAYMENT AMOUNT MISMATCH: " \
      "Payment ##{existing_payment.id} " \
      "has ₹#{existing_payment.amount.to_d}, " \
      "but current payable amount is ₹#{payable_amount}."
    )


    existing_payment.update!(
      status: "cancelled"
    )

  end


  # ==================================================
  # FIND OR CREATE FEE
  # ==================================================

  fee =
    @enrollment.fee ||
    @enrollment.build_fee


  # ------------------------------------------
  # Original course fee
  # ------------------------------------------

  fee.total_fee =
    @course.fee.to_d


  # ------------------------------------------
  # Apply course discount
  # ------------------------------------------

  if fee.discount_amount.to_d.zero? &&
     @course.has_active_discount?

    discount =
      @course.active_discount

    fee.discount_amount =
      discount.calculate_discount(@course.fee)

    fee.discount_name =
      discount.name

  end


  fee.paid_amount ||= 0


  # ------------------------------------------
  # Save Fee
  # ------------------------------------------

  fee.save!


  # ==================================================
  # CHECK ALREADY PAID
  # ==================================================

  if fee.paid_amount.to_d >= payable_amount

    @enrollment.update!(
      status: "Approved"
    )

    redirect_to learning_course_path(@course),
                notice: "Your course fee has already been paid."
    return

  end


  # ==================================================
  # RAZORPAY AMOUNT
  #
  # Database:
  #   ₹99
  #
  # Razorpay:
  #   9900 paise
  # ==================================================

  amount =
    (payable_amount * 100).to_i


  if amount <= 0

    redirect_to course_details_path(@course),
                alert: "Invalid course fee."
    return

  end


  # ==================================================
  # CREATE RAZORPAY ORDER
  # ==================================================

  razorpay_order =
    Razorpay::Order.create(
      amount: amount,
      currency: "INR",
      receipt:
        "enrollment_#{@enrollment.id}_#{Time.current.to_i}"
    )


  # ==================================================
  # CREATE PAYMENT RECORD
  #
  # Database stores RUPEES.
  # Razorpay receives PAISE.
  # ==================================================

  @enrollment.payments.create!(
    amount: payable_amount,
    razorpay_order_id: razorpay_order.id,
    status: "created"
  )


  # ==================================================
  # PAYMENT PAGE
  # ==================================================

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


if @enrollment.coupon.present?

  coupon = @enrollment.coupon

  # Safety check: same user cannot use same coupon twice
  unless coupon.already_used_by?(current_user)

    CouponUsage.create!(
      coupon: coupon,
      user: current_user,
      enrollment: @enrollment,
      discount_amount: @enrollment.discount_amount.to_d,
      used_at: Time.current
    )

    coupon.increment!(:used_count)

  end
end


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








  def apply_coupon
  @enrollment =
    current_user.enrollments.find(params[:id])

  @course =
    @enrollment.course

  # Do not allow coupon changes after approval
  if @enrollment.status == "Approved"
    redirect_to payment_path(@enrollment),
                alert: "You already have access to this course."
    return
  end

  # Do not allow coupon changes after successful payment
  if @enrollment.payments.where(status: "paid").exists?
    redirect_to payment_path(@enrollment),
                alert: "A payment has already been completed for this enrollment."
    return
  end

  code =
    params[:coupon_code].to_s.strip.upcase

  if code.blank?
    redirect_to payment_path(@enrollment),
                alert: "Please enter a coupon code."
    return
  end

  coupon =
    Coupon.find_by(code: code)

  unless coupon
    redirect_to payment_path(@enrollment),
                alert: "Invalid coupon code."
    return
  end

  # Coupon must belong to this course
  unless coupon.course_id == @course.id
    redirect_to payment_path(@enrollment),
                alert: "This coupon is not valid for this course."
    return
  end

  # Check active / expiry / student / previous usage
  unless coupon.available_for_user?(current_user)
    redirect_to payment_path(@enrollment),
                alert: "This coupon is not available for you or has already been used."
    return
  end

  # Apply coupon
  @enrollment.apply_coupon!(coupon)

  redirect_to payment_path(@enrollment),
              notice: "Coupon #{coupon.code} applied successfully."

rescue ActiveRecord::RecordInvalid => e

  Rails.logger.error(
    "COUPON APPLY ERROR: #{e.message}"
  )

  redirect_to payment_path(@enrollment),
              alert: "Unable to apply this coupon."

rescue StandardError => e

  Rails.logger.error(
    "COUPON ERROR: #{e.class} - #{e.message}"
  )

  redirect_to payment_path(@enrollment),
              alert: "Something went wrong while applying the coupon."
end
end
