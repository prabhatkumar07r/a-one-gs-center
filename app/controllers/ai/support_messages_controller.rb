module Ai
  class SupportMessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_support_request

    def index
      mark_unread_admin_messages_as_read

      messages =
        @support_request
          .messages
          .includes(:user)
          .chronological

      render json: {
        support_request: serialize_support_request,
        messages: messages.map { |message| serialize_message(message) }
      }
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "Support request not found."
      }, status: :not_found
    rescue StandardError => e
      Rails.logger.error(
        "[A ONE SUPPORT] #{e.class}: #{e.message}"
      )

      render json: {
        error: "Unable to load support messages."
      }, status: :unprocessable_entity
    end

    def create
      content = params.require(:content).to_s.strip

      if content.blank?
        return render json: {
          error: "Please enter a message."
        }, status: :unprocessable_entity
      end

      if content.length > 10_000
        return render json: {
          error: "Your message is too long."
        }, status: :unprocessable_entity
      end

      message =
        @support_request.messages.create!(
          user: current_user,
          sender_type: "student",
          content: content
        )

      if @support_request.status == "resolved" ||
         @support_request.status == "closed"

        @support_request.update!(
          status: "open",
          resolved_at: nil
        )
      end

      render json: {
        message: serialize_message(message),
        support_request: serialize_support_request
      }, status: :created
    rescue ActionController::ParameterMissing => e
      render json: {
        error: e.message
      }, status: :bad_request
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: e.record.errors.full_messages.to_sentence
      }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "Support request not found."
      }, status: :not_found
    rescue StandardError => e
      Rails.logger.error(
        "[A ONE SUPPORT] #{e.class}: #{e.message}"
      )

      render json: {
        error: "Unable to send your message."
      }, status: :unprocessable_entity
    end

    private

    def set_support_request
      @support_request =
        current_user
          .ai_support_requests
          .find(params[:support_request_id])
    end

    def mark_unread_admin_messages_as_read
      @support_request
        .messages
        .where(
          sender_type: "admin",
          read_at: nil
        )
        .where.not(user_id: current_user.id)
        .update_all(
          read_at: Time.current,
          updated_at: Time.current
        )
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

    def serialize_support_request
      {
        id: @support_request.id,
        subject: @support_request.subject,
        category: @support_request.category,
        category_label: @support_request.category_label,
        priority: @support_request.priority,
        priority_label: @support_request.priority_label,
        status: @support_request.status,
        status_label: @support_request.status_label,
        admin_reply: @support_request.admin_reply,
        replied_at: @support_request.replied_at,
        resolved_at: @support_request.resolved_at
      }
    end
  end
end