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
                courses.where("fee IS NULL OR fee <= 0")
              else
                courses.where("fee > 0")
              end
          end
        end

        page = [params[:page].to_i, 1].max

        per_page = params[:per_page].to_i
        per_page = PER_PAGE if per_page <= 0
        per_page = [per_page, MAX_PER_PAGE].min

        total_count = courses.count

        courses =
          courses
            .offset((page - 1) * per_page)
            .limit(per_page)

        render json: {
          success: true,
          data: {
            courses: courses.map { |course| course_json(course) },
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: (total_count.to_f / per_page).ceil
            }
          }
        }, status: :ok
      end

      def show
        course = Course.includes(:teacher).find(params[:id])

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

      def access
        course = Course.find(params[:id])

        unless course.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Course is not available."
          }, status: :not_found
        end

        enrollment =
          current_user.enrollments.find_by(course_id: course.id)

        if enrollment.nil?
          return render json: {
            success: true,
            data: {
              course_id: course.id,
              enrolled: false,
              status: nil,
              can_learn: false,
              payment_required: course.fee.to_d > 0
            }
          }, status: :ok
        end

        approved =
          enrollment.status.to_s.casecmp("Approved").zero?

        render json: {
          success: true,
          data: {
            course_id: course.id,
            enrolled: true,
            status: enrollment.status,
            can_learn: approved,
            payment_required: !approved
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Course not found."
        }, status: :not_found
      end

      def learning
        course =
          Course
            .includes(
              :quizzes,
              playlists: [
                :resources,
                :notes,
                {
                  videos: :notes
                }
              ]
            )
            .find(params[:id])

        unless course.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Course is not available."
          }, status: :not_found
        end

        enrollment =
          current_user.enrollments.find_by(course_id: course.id)

        unless enrollment &&
               enrollment.status.to_s.casecmp("Approved").zero?
          return render json: {
            success: false,
            error: "You do not have access to this course."
          }, status: :forbidden
        end

        playlists =
          course.playlists.map do |playlist|

            videos =
              playlist.videos
                      .where(status: :active)
                      .order(:position)

            {
              id: playlist.id,
              title: playlist.title,
              position: playlist.position,

              resources: playlist.resources.map do |resource|
                {
                  id: resource.id,
                  title: resource.title,
                  description: resource.description,
                  resource_type: resource.resource_type,
                  file_available: resource.file.attached?
                }
              end,

              notes: playlist.notes.map do |note|
                {
                  id: note.id,
                  title: note.title,
                  description: note.description,
                  category: note.category,
                  subject: note.subject,
                  file_available: note.pdf_file.attached?,
                  download_url:
                    note.pdf_file.attached? ?
                      Rails.application.routes.url_helpers
                        .download_api_v1_note_path(note.id) :
                      nil
                }
              end,

              videos: videos.map do |video|

                video_quizzes =
                  course.quizzes
                        .where(
                          video_id: video.id,
                          status: "Active"
                        )
                        .order(:id)

                {
                  id: video.id,
                  title: video.title,
                  position: video.position,
                  is_free: video.is_free,
                  youtube_id: video.youtube_id,
                  thumbnail: video.youtube_thumbnail,

                  notes: video.notes.map do |note|
                    {
                      id: note.id,
                      title: note.title,
                      description: note.description,
                      category: note.category,
                      subject: note.subject,
                      file_available: note.pdf_file.attached?
                    }
                  end,

                  quizzes: video_quizzes.map do |quiz|
                    {
                      id: quiz.id,
                      title: quiz.title,
                      description: quiz.description,
                      time_limit: quiz.time_limit,
                      passing_percentage: quiz.passing_percentage,
                      course_id: quiz.course_id,
                      video_id: quiz.video_id
                    }
                  end
                }
              end
            }
          end

        render json: {
          success: true,
          data: {
            course: {
              id: course.id,
              name: course.Course_name
            },
            playlists: playlists
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
        discount_percentage = course.discount_percentage.to_f

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
          original_fee: original_fee > 0 ? original_fee : nil,
          discount_percentage:
            discount_percentage > 0 ? discount_percentage : 0,
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