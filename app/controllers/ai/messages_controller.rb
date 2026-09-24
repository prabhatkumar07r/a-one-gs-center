module Ai
  class MessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_conversation

    def create
      user_message = params.require(:content).to_s.strip

      if user_message.blank?
        return render json: {
          error: "Please enter a message."
        }, status: :unprocessable_entity
      end

      if user_message.length > Ai::ChatService::MAX_USER_MESSAGE_LENGTH
        return render json: {
          error: "Your message is too long."
        }, status: :unprocessable_entity
      end

      # ---------------------------------------------------------
      # Call AI first
      # ---------------------------------------------------------

      result =
        Ai::ChatService.new(
          conversation: @conversation,
          user: current_user
        ).call(
          user_message: user_message
        )

      # ---------------------------------------------------------
      # Save user + assistant messages only after AI succeeds
      # ---------------------------------------------------------

      @conversation.transaction do
        @conversation.messages.create!(
          role: "user",
          content: user_message
        )

        @conversation.messages.create!(
          role: "assistant",
          content: result[:content],
          model: result[:model],
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens]
        )

        if @conversation.title == "New AI Chat"
          @conversation.update!(
            title: user_message.truncate(120)
          )
        end
      end

      assistant_message =
        @conversation.messages
                    .where(role: "assistant")
                    .order(created_at: :desc)
                    .first

      render json: {
        message: {
          id: assistant_message.id,
          role: assistant_message.role,
          content: assistant_message.content
        },
        conversation: {
          id: @conversation.id,
          title: @conversation.display_title
        },
        usage: {
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens]
        }
      }

    rescue ActionController::ParameterMissing => e
      render json: {
        error: e.message
      }, status: :bad_request

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "[A ONE AI] Database error: #{e.class}: #{e.message}"
      )

      render json: {
        error: "Unable to save your message."
      }, status: :unprocessable_entity

    rescue StandardError => e
      Rails.logger.error(
        "[A ONE AI] #{e.class}: #{e.message}"
      )

      render json: {
        error: e.message.presence ||
               "A ONE AI is temporarily unavailable."
      }, status: :unprocessable_entity
    end

    private

    def set_conversation
      @conversation =
        current_user.ai_conversations.find(
          params[:conversation_id]
        )
    end
  end
end