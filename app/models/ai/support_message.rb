module Ai
  class SupportMessage < ApplicationRecord
    self.table_name = "ai_support_messages"

    belongs_to :support_request,
               class_name: "Ai::SupportRequest",
               foreign_key: :ai_support_request_id

    belongs_to :user

    SENDER_TYPES = %w[
      student
      admin
    ].freeze

    validates :sender_type,
              inclusion: { in: SENDER_TYPES }

    validates :content,
              presence: true,
              length: { maximum: 10_000 }

    scope :chronological,
          -> { order(created_at: :asc) }

    scope :unread,
          -> { where(read_at: nil) }

    def student?
      sender_type == "student"
    end

    def admin?
      sender_type == "admin"
    end

    def mark_as_read!
      update!(read_at: Time.current)
    end
  end
end