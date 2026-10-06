module Api
  module V1
    class DashboardController < Api::ApplicationController

      def show
        enrollments =
          current_user
            .enrollments
            .includes(:course)
            .order(created_at: :desc)

        approved_enrollments =
          enrollments.select do |enrollment|
            enrollment.status.to_s.casecmp("Approved").zero?
          end

        pending_enrollments =
          enrollments.select do |enrollment|
            enrollment.status.to_s.casecmp("Pending").zero?
          end

        progress =
          current_user
            .video_progresses
            .includes(:video)

        completed_videos =
          progress.count { |item| item.completed }

        render json: {
          success: true,
          data: {
            student: {
              id: current_user.id,
              name: current_user.name,
              email: current_user.email
            },

            summary: {
              total_enrollments: enrollments.count,
              approved_courses: approved_enrollments.count,
              pending_courses: pending_enrollments.count,
              completed_videos: completed_videos,
              video_progress_count: progress.count
            },

            courses: enrollments.map do |enrollment|
              course = enrollment.course

              {
                enrollment_id: enrollment.id,
                course_id: course.id,
                course_name: course.Course_name,
                status: enrollment.status,
                can_learn:
                  enrollment.status.to_s.casecmp("Approved").zero?
              }
            end,

            recent_progress: progress
              .sort_by { |item| item.last_watched_at || item.updated_at }
              .reverse
              .first(10)
              .map do |item|
                {
                  video_id: item.video_id,
                  video_title: item.video.title,
                  completed: item.completed,
                  last_watched_at: item.last_watched_at
                }
              end
          }
        }, status: :ok
      end

    end
  end
end