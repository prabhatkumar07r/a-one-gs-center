module Ai
  class ConversationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_conversation, only: [:show, :destroy]

    def index
      @conversations =
        current_user.ai_conversations.recent.limit(50)

      @conversation = nil
    end

    def show
      @conversations =
        current_user.ai_conversations.recent.limit(50)

      render :index
    end

    def create
      conversation =
        current_user.ai_conversations.create!

      if request.format.json?
        render json: {
          conversation: {
            id: conversation.id,
            title: conversation.display_title
          },
          message_url:
            ai_conversation_messages_path(conversation)
        }, status: :created
      else
        redirect_to ai_conversation_path(conversation)
      end
    end

    def destroy
      @conversation.destroy!

      redirect_to ai_conversations_path,
                  notice: "AI chat deleted."
    end

    private

    def set_conversation
      @conversation =
        current_user.ai_conversations.find(params[:id])
    end
  end
end