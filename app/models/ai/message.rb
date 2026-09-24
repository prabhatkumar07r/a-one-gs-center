module Ai
  class Message < ApplicationRecord
    self.table_name = "ai_messages"

    belongs_to :conversation,
               class_name: "Ai::Conversation",
               foreign_key: :ai_conversation_id

    validates :role, inclusion: { in: %w[user assistant] }

    validates :content, presence: true

    validates :content, length: { maximum: 20_000 }

    scope :chronological, -> { order(:created_at) }
  end
end