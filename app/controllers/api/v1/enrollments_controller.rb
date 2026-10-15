
module Api
  module V1
    class EnrollmentsController < Api::ApplicationController

      def index
        enrollments =
          current_user
            .enrollments
            .includes(:course, :payments)
            .order(created_at: :desc)

        render json: {
          success: true,
          data: {
            enrollments: enrollments.map do |enrollment|
              enrollment_json(enrollment)
            end
          }
        }, status: :ok
      end

      def show
        enrollment =
          current_user
            .enrollments
            .includes(:course, :payments)
            .find(params[:id])

        render json: {
          success: true,
          data: {
            enrollment: enrollment_json(enrollment)
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Enrollment not found."
        }, status: :not_found
      end


def create
  course = Course.where(id: params[:course_id])
                 .where("LOWER(status) = ?", "active")
                 .first

  unless course
    return render json: {
      success: false,
      error: "Course not found or unavailable."
    }, status: :not_found
  end

  enrollment = nil
  coupon_code = params[:coupon_code].to_s.strip.upcase

  Enrollment.transaction do
    enrollment = current_user.enrollments.lock.find_by(
      course_id: course.id
    )

    if enrollment&.status == "Approved"
      # Existing approved enrollment ko change nahi karna.
    else
      if enrollment.nil?
        enrollment = current_user.enrollments.create!(
          course: course,
          status: "Pending"
        )
      end

      if course.free?
        enrollment.update!(status: "Approved")
      else
        fee = enrollment.fee || enrollment.build_fee
        fee.total_fee = course.fee.to_d
        fee.save!

        if coupon_code.present?
          coupon = Coupon.find_by(
            "LOWER(code) = ?",
            coupon_code.downcase
          )

          unless coupon &&
                 coupon.available_for_user?(current_user) &&
                 coupon.applicable_to?(course)
            raise ActiveRecord::RecordInvalid.new(
              enrollment.tap do |e|
                e.errors.add(:coupon, "is invalid or unavailable")
              end
            )
          end

          enrollment.apply_coupon!(coupon)
        else
          enrollment.remove_coupon! if enrollment.coupon.present?
        end
      end
    end
  end

  render json: {
    success: true,
    message: course.free? ?
      "Free course enrollment successful." :
      "Enrollment created. Payment is required.",
    data: {
      enrollment: enrollment_json(enrollment.reload),
      payment_required: !course.free?
    }
  }, status: :ok

rescue ActiveRecord::RecordInvalid => e
  render json: {
    success: false,
    error: e.record.errors.full_messages.to_sentence
  }, status: :unprocessable_entity
end


      private

      def enrollment_json(enrollment)
        course = enrollment.course

        {
          id: enrollment.id,
          status: enrollment.status,
          original_amount: enrollment.original_amount.to_f,
          discount_amount: enrollment.discount_amount.to_f,
          final_amount: enrollment.final_amount.to_f,
          payable_amount: enrollment.payable_amount.to_f,
          created_at: enrollment.created_at,

          course: {
            id: course.id,
            name: course.Course_name,
            fee: course.fee.to_f,
            is_free: course.free?
          },

          payments: enrollment.payments
                              .order(created_at: :desc)
                              .map do |payment|
            {
              id: payment.id,
              amount: payment.amount.to_d.to_f,
              currency: "INR",
              status: payment.status,
              razorpay_order_id: payment.razorpay_order_id,
              razorpay_payment_id: payment.razorpay_payment_id,
              created_at: payment.created_at
            }
          end
        }
      end

    end
  end
end
