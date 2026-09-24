module Ai
  class SupportRequest < ApplicationRecord
    self.table_name = "ai_support_requests"

    belongs_to :user

    belongs_to :ai_conversation,
               class_name: "Ai::Conversation",
               foreign_key: :ai_conversation_id

    belongs_to :admin_user,
               class_name: "User",
               foreign_key: :admin_user_id,
               optional: true

    has_many :messages,
             class_name: "Ai::SupportMessage",
             foreign_key: :ai_support_request_id,
             dependent: :destroy

    CATEGORIES = %w[
      course_access
      enrollment
      payment
      refund
      technical
      account
      content
      other
    ].freeze

    STATUSES = %w[
      open
      in_progress
      resolved
      closed
    ].freeze

    PRIORITIES = %w[
      normal
      high
      urgent
    ].freeze

    validates :category,
              inclusion: { in: CATEGORIES }

    validates :status,
              inclusion: { in: STATUSES }

    validates :priority,
              inclusion: { in: PRIORITIES }

    validates :subject,
              presence: true,
              length: { maximum: 160 }

    validates :description,
              presence: true,
              length: { maximum: 10_000 }

    validates :ai_context,
              length: { maximum: 20_000 },
              allow_blank: true

    validates :admin_reply,
              length: { maximum: 10_000 },
              allow_blank: true

    scope :recent,
          -> { order(created_at: :desc) }

    scope :open_items,
          -> { where(status: %w[open in_progress]) }

    def category_label
      category.to_s.tr("_", " ").titleize
    end

    def status_label
      status.to_s.tr("_", " ").titleize
    end

    def priority_label
      priority.to_s.titleize
    end
  end
end