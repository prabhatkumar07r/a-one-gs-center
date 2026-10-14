
module Api
  module V1
    class AchievementsController < Api::ApplicationController
        skip_before_action :authenticate_request, only: [:index]
      def index
        achievements = Achievement
          .active
          .preload(
            { photo_attachment: :blob },
            { video_attachment: :blob }
          )
          .order(created_at: :desc)
          .limit(6)

        render json: {
          success: true,
          data: {
            achievements: achievements.map do |achievement|
              serialize_achievement(achievement)
            end
          }
        }, status: :ok
      end

      private

      def serialize_achievement(achievement)
        host = ENV.fetch("APP_HOST", "https://aonegscenter.com")

        {
          id: achievement.id,
          title: achievement.title,
          student_name: achievement.student_name,
          rank: achievement.rank,
          year: achievement.year,
          description: achievement.description,
          status: achievement.status,
          photo_url: achievement.photo.attached? ?
            Rails.application.routes.url_helpers.rails_blob_url(
              achievement.photo,
              host: host
            ) : nil,
          video_url: achievement.video.attached? ?
            Rails.application.routes.url_helpers.rails_blob_url(
              achievement.video,
              host: host
            ) : nil,
          created_at: achievement.created_at
        }
      end
    end
  end
end
