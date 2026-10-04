class PaymentsController < ApplicationController
  before_action :authenticate_user!

  def show
    @enrollment =
      current_user.enrollments.find(params[:id])

    @course =
      @enrollment.course

    if @course.free?
      redirect_to course_details_path(@course),
                  alert: "This course is free. No payment is required."
      return
    end

    if @enrollment.status == "Approved"
      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."
      return
    end

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

    @payment =
      @enrollment.payments
                 .where(status: ["created", "pending"])
                 .order(created_at: :desc)
                 .first

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

  def create
    @enrollment =
      current_user.enrollments.find(params[:id])

    @course =
      @enrollment.course

    if @course.free?
      @enrollment.update!(
        status: "Approved"
      )

      redirect_to learning_course_path(@course),
                  notice: "You have been enrolled in this free course."
      return
    end

    if @enrollment.status == "Approved"
      redirect_to learning_course_path(@course),
                  notice: "You already have access to this course."
      return
    end

    payable_amount =
      @enrollment.payable_amount.to_d

    if payable_amount <= 0
      redirect_to course_details_path(@course),
                  alert: "Invalid course fee."
      return
    end

    existing_payment =
      @enrollment.payments
                 .where(status: ["created", "pending"])
                 .order(created_at: :desc)
                 .first

    if existing_payment.present?
      if existing_payment.amount.to_d == payable_amount
        redirect_to payment_path(@enrollment)
        return
      end

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

    fee =
      @enrollment.fee ||
      @enrollment.build_fee

    fee.total_fee =
      @course.fee.to_d

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

    fee.save!

    if fee.paid_amount.to_d >= payable_amount
      @enrollment.update!(
        status: "Approved"
      )

      redirect_to learning_course_path(@course),
                  notice: "Your course fee has already been paid."
      return
    end

    amount =
      (payable_amount * 100).to_i

    if amount <= 0
      redirect_to course_details_path(@course),
                  alert: "Invalid course fee."
      return
    end

    razorpay_order =
      Razorpay::Order.create(
        amount: amount,
        currency: "INR",
        receipt:
          "enrollment_#{@enrollment.id}_#{Time.current.to_i}"
      )

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

  def verify
    @enrollment =
      current_user.enrollments.find(params[:id])

    razorpay_payment_id =
      params[:razorpay_payment_id].to_s.strip

    razorpay_order_id =
      params[:razorpay_order_id].to_s.strip

    razorpay_signature =
      params[:razorpay_signature].to_s.strip

    if razorpay_payment_id.blank? ||
       razorpay_order_id.blank? ||
       razorpay_signature.blank?

      redirect_to payment_path(@enrollment),
                  alert: "Payment verification details are incomplete."
      return
    end

    begin
      payment =
        @enrollment.payments.find_by!(
          razorpay_order_id: razorpay_order_id
        )

      if payment.paid?
        redirect_to student_dashboard_path,
                    notice: "Payment has already been verified."
        return
      end

      generated_signature =
        OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new("SHA256"),
          ENV.fetch("RAZORPAY_KEY_SECRET"),
          "#{payment.razorpay_order_id}|#{razorpay_payment_id}"
        )

      unless ActiveSupport::SecurityUtils.secure_compare(
        generated_signature,
        razorpay_signature
      )

        redirect_to payment_path(@enrollment),
                    alert: "Payment verification failed."
        return
      end

      result =
        RazorpayPaymentCompletionService.call(
          payment: payment,
          razorpay_payment_id: razorpay_payment_id,
          razorpay_order_id: razorpay_order_id
        )

      if result.success
        if result.already_paid
          redirect_to student_dashboard_path,
                      notice: "Payment has already been verified."
        else
          redirect_to student_dashboard_path,
                      notice: "Payment successful. Your enrollment is now approved."
        end

        return
      end

      Rails.logger.error(
        "[PAYMENT VERIFY] #{result.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert: result.message

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error(
        "[PAYMENT VERIFY] Record not found: #{e.message}"
      )

      redirect_to payment_path(@enrollment),
                  alert: "Payment record could not be found."

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

  def apply_coupon
    @enrollment =
      current_user.enrollments.find(params[:id])

    @course =
      @enrollment.course

    if @enrollment.status == "Approved"
      redirect_to payment_path(@enrollment),
                  alert: "You already have access to this course."
      return
    end

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

    unless coupon.applicable_to?(@course)
      redirect_to payment_path(@enrollment),
                  alert: "This coupon is not valid for this course."
      return
    end

    unless coupon.available_for_user?(current_user)
      redirect_to payment_path(@enrollment),
                  alert: "This coupon is not available for you or has already been used."
      return
    end

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

  def remove_coupon
    @enrollment =
      current_user.enrollments.find(params[:id])

    if @enrollment.status == "Approved"
      redirect_to payment_path(@enrollment),
                  alert: "You already have access to this course."
      return
    end

    if @enrollment.payments.where(status: "paid").exists?
      redirect_to payment_path(@enrollment),
                  alert: "A payment has already been completed."
      return
    end

    unless @enrollment.coupon.present?
      redirect_to payment_path(@enrollment),
                  alert: "No coupon is currently applied."
      return
    end

    @enrollment.remove_coupon!

    redirect_to payment_path(@enrollment),
                notice: "Coupon removed successfully."

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path,
                alert: "Enrollment not found."

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(
      "COURSE COUPON REMOVE ERROR: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Unable to remove coupon."

  rescue StandardError => e
    Rails.logger.error(
      "COURSE COUPON REMOVE ERROR: " \
      "#{e.class}: #{e.message}"
    )

    redirect_to payment_path(@enrollment),
                alert: "Something went wrong."
  end
end