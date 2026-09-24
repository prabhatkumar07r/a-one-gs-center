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
  @enrollment = current_user.enrollments.find(params[:enrollment_id])

  razorpay_payment_id = params[:razorpay_payment_id].to_s.strip
  razorpay_order_id   = params[:razorpay_order_id].to_s.strip
  razorpay_signature  = params[:razorpay_signature].to_s.strip

  if razorpay_payment_id.blank? ||
     razorpay_order_id.blank? ||
     razorpay_signature.blank?

    redirect_to payment_path(@enrollment),
                alert: "Payment verification details are incomplete."
    return
  end

  begin
    payment = @enrollment.payments.find_by!(
      razorpay_order_id: razorpay_order_id
    )

    # =========================================================
    # PREVENT DUPLICATE VERIFICATION
    # =========================================================

    if payment.paid?
      redirect_to student_dashboard_path,
                  notice: "Payment has already been verified."
      return
    end

    # =========================================================
    # VERIFY RAZORPAY SIGNATURE
    # =========================================================

    razorpay_order_id_for_signature = payment.razorpay_order_id

    generated_signature =
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("SHA256"),
        ENV.fetch("RAZORPAY_KEY_SECRET"),
        "#{razorpay_order_id_for_signature}|#{razorpay_payment_id}"
      )

    unless ActiveSupport::SecurityUtils.secure_compare(
      generated_signature,
      razorpay_signature
    )
      redirect_to payment_path(@enrollment),
                  alert: "Payment verification failed."
      return
    end

    # =========================================================
    # DATABASE TRANSACTION
    # =========================================================

    ActiveRecord::Base.transaction do

      # -------------------------------------------------------
      # MARK PAYMENT AS PAID
      # -------------------------------------------------------

      payment.update!(
        status: "paid",
        razorpay_payment_id: razorpay_payment_id
      )

      # -------------------------------------------------------
      # CREATE / UPDATE FEE
      # -------------------------------------------------------

      fee = @enrollment.fee ||
            @enrollment.build_fee(
              user: current_user,
              course: @enrollment.course
            )

      fee.amount =
        @enrollment.course_price.to_d

      fee.discount_amount =
        @enrollment.discount_amount.to_d

      fee.paid_amount =
        fee.paid_amount.to_d + payment.amount.to_d

      fee.save!

      # -------------------------------------------------------
      # RECORD COUPON USAGE
      # -------------------------------------------------------

      if @enrollment.coupon.present?

        coupon = @enrollment.coupon

        unless coupon.already_used_by?(current_user)

          CouponUsage.create!(
            coupon: coupon,
            user: current_user,
            enrollment: @enrollment,
            discount_amount: @enrollment.discount_amount.to_d,
            used_at: Time.current
          )
        end

        # Keep the denormalized counter synchronized
        coupon.update!(
          used_count: coupon.coupon_usages.count
        )
      end

      # -------------------------------------------------------
      # APPROVE ENROLLMENT
      # -------------------------------------------------------

      @enrollment.update!(
        status: "Approved"
      )
    end

    # =========================================================
    # SUCCESS
    # =========================================================

    redirect_to student_dashboard_path,
                notice: "Payment successful. Your enrollment is now approved."

  rescue ActiveRecord::RecordNotFound
    redirect_to payment_path(@enrollment),
                alert: "Payment record could not be found."

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      "[PAYMENT VERIFY] Record validation failed: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Payment could not be completed. Please contact support."

  rescue StandardError => e
    Rails.logger.error(
      "[PAYMENT VERIFY] #{e.class}: #{e.message}"
    )

    Rails.logger.error(
      e.backtrace.first(20).join("\n")
    )

    redirect_to payment_path(@enrollment),
                alert: "Payment verification failed. Please contact support."
  end
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
