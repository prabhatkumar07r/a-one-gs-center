module Ai
  class Conversation < ApplicationRecord
    self.table_name = "ai_conversations"

    belongs_to :user

    has_many :messages,
             class_name: "Ai::Message",
             foreign_key: :ai_conversation_id,
             dependent: :destroy

    validates :title, length: { maximum: 120 }

    scope :recent, -> { order(updated_at: :desc) }

    def display_title
      title.presence ||
        messages.where(role: "user").order(:created_at).first&.content&.truncate(60) ||
        "New AI Chat"
    end
  end
end