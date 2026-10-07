
module Api
  module V1
    class SupportRequestsController < Api::ApplicationController

      def index
        support_requests =
          current_user
            .ai_support_requests
            .recent
            .limit(20)

        render json: {
          success: true,
          data: {
            support_requests: support_requests.map do |support_request|
              serialize_support_request(support_request)
            end
          }
        }, status: :ok
      end

      def show
        support_request =
          current_user
            .ai_support_requests
            .find(params[:id])

        render json: {
          success: true,
          data: {
            support_request: serialize_support_request(support_request),
            messages: support_request
              .messages
              .includes(:user)
              .chronological
              .map { |message| serialize_message(message) }
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Support request not found."
        }, status: :not_found
      end

      def create
        conversation = find_or_create_conversation

        ai_context = build_ai_context(conversation)

        support_request =
          current_user.ai_support_requests.create!(
            ai_conversation: conversation,
            category: support_request_params[:category].presence || "other",
            subject: support_request_params[:subject],
            description: support_request_params[:description],
            ai_context: ai_context
          )

        render json: {
          success: true,
          message: "Support request created successfully.",
          data: {
            support_request: serialize_support_request(support_request)
          }
        }, status: :created

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "AI conversation not found."
        }, status: :not_found

      rescue ActionController::ParameterMissing => e
        render json: {
          success: false,
          error: e.message
        }, status: :bad_request

      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error: e.record.errors.full_messages.to_sentence
        }, status: :unprocessable_entity
      end

      private

      def support_request_params
        params.require(:support_request).permit(
          :ai_conversation_id,
          :category,
          :subject,
          :description
        )
      end

      def find_or_create_conversation
        conversation_id =
          support_request_params[:ai_conversation_id].presence

        if conversation_id
          current_user.ai_conversations.find(conversation_id)
        else
          current_user.ai_conversations.create!(
            title: "Support Request"
          )
        end
      end

      def build_ai_context(conversation)
        conversation
          .messages
          .chronological
          .last(10)
          .map do |message|
            "#{message.role.to_s.titleize}: #{message.content}"
          end
          .join("\n")
          .truncate(20_000)
      end

      def serialize_support_request(support_request)
        {
          id: support_request.id,
          subject: support_request.subject,
          description: support_request.description,
          category: support_request.category,
          category_label: support_request.category_label,
          priority: support_request.priority,
          priority_label: support_request.priority_label,
          status: support_request.status,
          status_label: support_request.status_label,
          admin_reply: support_request.admin_reply,
          replied_at: support_request.replied_at,
          resolved_at: support_request.resolved_at,
          created_at: support_request.created_at,
          updated_at: support_request.updated_at
        }
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
