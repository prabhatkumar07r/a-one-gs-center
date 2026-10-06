module Api
  module V1
    class SupportMessagesController < Api::ApplicationController

      def index
        support_request = current_user.ai_support_requests.find(
          params[:support_request_id]
        )

        messages =
          support_request
            .messages
            .includes(:user)
            .chronological

        render json: {
          success: true,
          data: {
            support_request_id: support_request.id,
            messages: messages.map { |message| serialize_message(message) }
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Support request not found."
        }, status: :not_found
      end

      def create
        support_request =
          current_user.ai_support_requests.find(
            params[:support_request_id]
          )

        message =
          support_request.messages.create!(
            user: current_user,
            sender_type: "student",
            content: message_params[:content]
          )

        render json: {
          success: true,
          message: "Message sent successfully.",
          data: {
            message: serialize_message(message)
          }
        }, status: :created

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Support request not found."
        }, status: :not_found

      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error: e.record.errors.full_messages.to_sentence
        }, status: :unprocessable_entity
      end

      private

      def message_params
        params.require(:message).permit(:content)
      end

      def serialize_message(message)
        {
          id: message.id,
          sender_type: message.sender_type,
          content: message.content,
          created_at: message.created_at,
          read_at: message.read_at,
          sender: {
            id: message.user_id,
            name:
              if message.user.respond_to?(:name) &&
                 message.user.name.present?
                message.user.name
              else
                message.user.email
              end
          }
        }
      end
    end
  end
end