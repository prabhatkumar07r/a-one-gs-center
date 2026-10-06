module Api
  module V1
    class EnrollmentsController < Api::ApplicationController

      def index
        enrollments =
          current_user
            .enrollments
            .includes(:course)
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
      .includes(:course)
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
          }
        }
      end

    end
  end
end