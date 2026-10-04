module Api
  module V1
    class CoursesController < Api::ApplicationController
      PER_PAGE = 10
      MAX_PER_PAGE = 30

      def index
        courses = Course
          .includes(:teacher)
          .where(status: "Active")
          .order(created_at: :desc)

        if params[:search].present?
          search = "%#{params[:search].to_s.strip.downcase}%"

          courses = courses.where(
            "LOWER(\"Course_name\") LIKE :search
             OR LOWER(description) LIKE :search",
            search: search
          )
        end

        if params[:type].present?
          type = params[:type].to_s.strip.downcase

          if %w[free paid].include?(type)
            courses =
              if type == "free"
                courses.where(
                  "fee IS NULL OR fee <= 0"
                )
              else
                courses.where(
                  "fee > 0"
                )
              end
          end
        end

        page =
          [params[:page].to_i, 1].max

        per_page =
          params[:per_page].to_i

        per_page =
          PER_PAGE if per_page <= 0

        per_page =
          [per_page, MAX_PER_PAGE].min

        total_count = courses.count

        courses =
          courses
            .offset((page - 1) * per_page)
            .limit(per_page)

        render json: {
          success: true,
          data: {
            courses: courses.map do |course|
              course_json(course)
            end,
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages:
                (total_count.to_f / per_page).ceil
            }
          }
        }, status: :ok
      end

      def show
        course = Course
          .includes(:teacher)
          .find(params[:id])

        unless course.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Course is not available."
          }, status: :not_found
        end

        render json: {
          success: true,
          data: {
            course: course_json(course)
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Course not found."
        }, status: :not_found
      end

      private

      def course_json(course)
        fee = course.fee.to_f
        original_fee = course.original_fee.to_f

        discount_percentage =
          course.discount_percentage.to_f

        if discount_percentage <= 0 &&
            original_fee > fee &&
            original_fee > 0

          discount_percentage =
            ((original_fee - fee) / original_fee * 100).round
        end

        {
          id: course.id,
          name: course.Course_name,
          description: course.description,
          course_type: course.course_type,
          fee: fee,
          original_fee:
            original_fee > 0 ? original_fee : nil,
          discount_percentage:
            discount_percentage > 0 ?
              discount_percentage : 0,
          duration: course.duration,
          learning_outcomes: course.learning_outcomes,
          requirements: course.requirements,
          status: course.status,

          teacher: {
            id: course.teacher&.id,
            name: course.teacher&.name
          },

          is_free: fee <= 0
        }
      end
    end
  end
end