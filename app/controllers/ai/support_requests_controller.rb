module Ai
  class SupportRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_support_request, only: [:show]

    def index
      support_requests =
        current_user
          .ai_support_requests
          .recent
          .limit(20)

      respond_to do |format|
        format.html

        format.json do
          render json: {
            support_requests: support_requests.map do |support_request|
              serialize_support_request(support_request)
            end
          }
        end
      end
    rescue StandardError => e
      Rails.logger.error("[A ONE SUPPORT] #{e.class}: #{e.message}")

      respond_to do |format|
        format.html do
          redirect_to root_path,
                      alert: "Unable to load support requests."
        end

        format.json do
          render json: {
            error: "Unable to load support requests."
          }, status: :unprocessable_entity
        end
      end
    end

    def show
      respond_to do |format|
        format.html

        format.json do
          render json: {
            support_request: serialize_support_request(@support_request),
            messages: @support_request
              .messages
              .includes(:user)
              .chronological
              .map { |message| serialize_message(message) }
          }
        end
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html do
          redirect_to ai_support_requests_path,
                      alert: "Support request not found."
        end

        format.json do
          render json: {
            error: "Support request not found."
          }, status: :not_found
        end
      end
    end

    def create
      conversation =
        current_user.ai_conversations.find(
          support_request_params[:ai_conversation_id]
        )

      ai_context = build_ai_context(conversation)

      support_request =
        current_user.ai_support_requests.create!(
          ai_conversation: conversation,
          category: support_request_params[:category],
          subject: support_request_params[:subject],
          description: support_request_params[:description],
          ai_context: ai_context
        )

      render json: {
        support_request: serialize_support_request(support_request)
      }, status: :created
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "AI conversation not found."
      }, status: :not_found
    rescue ActionController::ParameterMissing => e
      render json: {
        error: e.message
      }, status: :bad_request
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: e.record.errors.full_messages.to_sentence
      }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("[A ONE SUPPORT] #{e.class}: #{e.message}")

      render json: {
        error: e.message.presence || "Unable to create support request."
      }, status: :unprocessable_entity
    end

    private

    def set_support_request
      @support_request =
        current_user
          .ai_support_requests
          .find(params[:id])
    end

    def support_request_params
      params.require(:support_request).permit(
        :ai_conversation_id,
        :category,
        :subject,
        :description
      )
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