module Api
  module V1
    class NotificationsController < Api::ApplicationController

      def index
        notifications = Notification.active

        render json: {
          success: true,
          data: {
            notifications: notifications.map do |notification|
              serialize_notification(notification)
            end
          }
        }, status: :ok
      end

      private

      def serialize_notification(notification)
        {
          id: notification.id,
          title: notification.title,
          description: notification.description,
          notification_type: notification.notification_type,
          start_date: notification.start_date,
          end_date: notification.end_date,
          status: notification.status,
          created_at: notification.created_at,
          updated_at: notification.updated_at
        }
      end
    end
  end
end