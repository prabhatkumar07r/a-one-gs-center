module Api
  module V1
    class VideosController < Api::ApplicationController

      def progress
        video = Video.find(params[:id])

        unless video.active?
          return render json: {
            success: false,
            error: "Video is not available."
          }, status: :not_found
        end

        enrollment =
          current_user.enrollments.find_by(
            course_id: video.course_id,
            status: "Approved"
          )

        unless enrollment
          return render json: {
            success: false,
            error: "You do not have access to this video."
          }, status: :forbidden
        end

        video_progress =
          VideoProgress.find_or_initialize_by(
            user_id: current_user.id,
            video_id: video.id
          )

        if request.get?
          return render json: {
            success: true,
            data: {
              video_id: video.id,
              completed: video_progress.persisted? ? video_progress.completed : false,
              last_watched_at: video_progress.last_watched_at
            }
          }, status: :ok
        end

        completed_value = params[:completed].to_s.downcase

        unless %w[true false].include?(completed_value)
          return render json: {
            success: false,
            error: 'completed must be true or false.'
          }, status: :unprocessable_entity
        end

        video_progress.completed = (completed_value == 'true')

        video_progress.last_watched_at = Time.current

        video_progress.save!
        render json: {
          success: true,
          message: "Video progress saved successfully.",
          data: {
            video_id: video.id,
            completed: video_progress.completed,
            last_watched_at: video_progress.last_watched_at
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Video not found."
        }, status: :not_found

      rescue ActiveRecord::RecordInvalid
        render json: {
          success: false,
          error: "Unable to save video progress."
        }, status: :unprocessable_entity
      end

    end
  end
end


