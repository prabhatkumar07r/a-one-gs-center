module Api
  module V1
    class PaymentsController < Api::ApplicationController

      def create
        enrollment =
          current_user.enrollments
                      .includes(:course, :fee)
                      .find(params[:enrollment_id])

        course = enrollment.course

        if course.free?
          return render json: {
            success: false,
            error: "This course is free. No payment is required."
          }, status: :unprocessable_entity
        end

        if enrollment.status == "Approved"
          return render json: {
            success: false,
            error: "You already have access to this course."
          }, status: :unprocessable_entity
        end

        payable_amount =
          enrollment.payable_amount.to_d

        if payable_amount <= 0
          return render json: {
            success: false,
            error: "Invalid course fee."
          }, status: :unprocessable_entity
        end

        existing_payment =
          enrollment.payments
                    .where(status: ["created", "pending"])
                    .order(created_at: :desc)
                    .first

        if existing_payment.present?
          if existing_payment.amount.to_d == payable_amount
            return render json: {
              success: true,
              message: "Existing payment order found.",
              data: payment_json(existing_payment)
            }, status: :ok
          end

          existing_payment.update!(
            status: "cancelled"
          )
        end

        fee =
          enrollment.fee ||
          enrollment.build_fee

        fee.total_fee =
          course.fee.to_d

        if fee.discount_amount.to_d.zero? &&
           course.has_active_discount?

          discount =
            course.active_discount

          fee.discount_amount =
            discount.calculate_discount(course.fee)

          fee.discount_name =
            discount.name
        end

        fee.paid_amount ||= 0
        fee.save!

        if fee.paid_amount.to_d >= payable_amount
          enrollment.update!(
            status: "Approved"
          )

          return render json: {
            success: true,
            message: "Your course fee has already been paid.",
            data: {
              enrollment_id: enrollment.id,
              status: enrollment.status
            }
          }, status: :ok
        end

        amount_paise =
          (payable_amount * 100).to_i

        if amount_paise <= 0
          return render json: {
            success: false,
            error: "Invalid course fee."
          }, status: :unprocessable_entity
        end

        razorpay_order =
          Razorpay::Order.create(
            amount: amount_paise,
            currency: "INR",
            receipt:
              "enrollment_#{enrollment.id}_#{Time.current.to_i}"
          )

        payment =
          enrollment.payments.create!(
            amount: payable_amount,
            razorpay_order_id: razorpay_order.id,
            status: "created"
          )

        render json: {
          success: true,
          message: "Payment order created successfully.",
          data: payment_json(payment)
        }, status: :created

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Enrollment not found."
        }, status: :not_found

      rescue Razorpay::Error => e
        Rails.logger.error(
          "API RAZORPAY ORDER ERROR: #{e.message}"
        )

        render json: {
          success: false,
          error: "Unable to create payment. Please try again."
        }, status: :unprocessable_entity

      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error(
          "API PAYMENT/FEE RECORD ERROR: #{e.message}"
        )

        render json: {
          success: false,
          error: "Unable to create payment record."
        }, status: :unprocessable_entity
      end
      def verify
  payment =
    current_user
      .enrollments
      .joins(:payments)
      .merge(Payment.where(id: params[:id]))
      .first
      &.payments
      &.find_by(id: params[:id])

  unless payment
    return render json: {
      success: false,
      error: "Payment not found."
    }, status: :not_found
  end

  enrollment = payment.enrollment

  razorpay_payment_id =
    params[:razorpay_payment_id].to_s.strip

  razorpay_order_id =
    params[:razorpay_order_id].to_s.strip

  razorpay_signature =
    params[:razorpay_signature].to_s.strip

  if razorpay_payment_id.blank? ||
     razorpay_order_id.blank? ||
     razorpay_signature.blank?

    return render json: {
      success: false,
      error: "Payment verification details are incomplete."
    }, status: :unprocessable_entity
  end

  begin
    unless payment.razorpay_order_id.to_s == razorpay_order_id
      return render json: {
        success: false,
        error: "Razorpay order does not match the local payment."
      }, status: :unprocessable_entity
    end

    if payment.paid?
      return render json: {
        success: true,
        message: "Payment has already been verified.",
        data: {
          payment_id: payment.id,
          enrollment_id: enrollment.id,
          payment_status: payment.status,
          enrollment_status: enrollment.status
        }
      }, status: :ok
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
      return render json: {
        success: false,
        error: "Payment verification failed."
      }, status: :unprocessable_entity
    end

    result =
      RazorpayPaymentCompletionService.call(
        payment: payment,
        razorpay_payment_id: razorpay_payment_id,
        razorpay_order_id: razorpay_order_id
      )

    if result.success
      return render json: {
        success: true,
        message: result.message,
        data: {
          payment_id: result.payment.id,
          enrollment_id: enrollment.id,
          payment_status: result.payment.status,
          enrollment_status: enrollment.reload.status,
          already_paid: result.already_paid
        }
      }, status: :ok
    end

    render json: {
      success: false,
      error: result.message
    }, status: :unprocessable_entity

  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "Payment record could not be found."
    }, status: :not_found

  rescue StandardError => e
    Rails.logger.error(
      "[API PAYMENT VERIFY] #{e.class}: #{e.message}"
    )

    Rails.logger.error(
      e.backtrace.first(20).join("\n")
    )

    render json: {
      success: false,
      error: "Payment verification failed. Please contact support."
    }, status: :unprocessable_entity
  end
end

def show
  payment =
    current_user
      .enrollments
      .joins(:payments)
      .merge(Payment.where(id: params[:id]))
      .first
      &.payments
      &.find_by(id: params[:id])

  unless payment
    return render json: {
      success: false,
      error: "Payment not found."
    }, status: :not_found
  end

  enrollment = payment.enrollment
  course = enrollment.course

  render json: {
    success: true,
    data: {
      payment: {
        id: payment.id,
        enrollment_id: enrollment.id,
        amount: payment.amount.to_d.to_f,
        currency: "INR",
        razorpay_order_id: payment.razorpay_order_id,
        status: payment.status,
        created_at: payment.created_at
      },
      enrollment: {
        id: enrollment.id,
        status: enrollment.status
      },
      course: {
        id: course.id,
        name: course.Course_name,
        fee: course.fee.to_d.to_f
      }
    }
  }, status: :ok

rescue ActiveRecord::RecordNotFound
  render json: {
    success: false,
    error: "Payment not found."
  }, status: :not_found
end

      private

      def payment_json(payment)
        {
          id: payment.id,
          enrollment_id: payment.enrollment_id,
          amount: payment.amount.to_d.to_f,
          currency: "INR",
          razorpay_order_id: payment.razorpay_order_id,
          status: payment.status,
          created_at: payment.created_at
        }
      end

    end
  end
end