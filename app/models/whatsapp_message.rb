class WhatsappMessage < ApplicationRecord
  belongs_to :user, optional: true

  STATUSES = %w[
    sent
    delivered
    read
    failed
  ].freeze

  validates :phone_number, presence: true

  validates :whatsapp_message_id,
            presence: true,
            uniqueness: true

  validates :message_type,
            presence: true

  validates :direction,
            inclusion: {
              in: %w[incoming outgoing]
            }

  validates :status,
            inclusion: {
              in: STATUSES
            }

  scope :incoming, -> {
    where(direction: "incoming")
  }

  scope :outgoing, -> {
    where(direction: "outgoing")
  }

  scope :unread, -> {
    where(read_at: nil)
  }

  def incoming?
    direction == "incoming"
  end

  def outgoing?
    direction == "outgoing"
  end

  def read?
    read_at.present?
  end

  def sent?
    status == "sent"
  end

  def delivered?
    status == "delivered"
  end

  def read_status?
    status == "read"
  end

  def failed?
    status == "failed"
  end

  def conversation_key
    phone_number.to_s.gsub(/\D/, "")
  end

  def status_icon
    return "!" if failed?
    return "✓✓" if read_status?
    return "✓✓" if delivered?
    return "✓" if sent?

    ""
  end
end