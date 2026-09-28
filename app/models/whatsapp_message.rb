class WhatsappMessage < ApplicationRecord
  belongs_to :user, optional: true

  validates :phone_number, presence: true
  validates :whatsapp_message_id, presence: true, uniqueness: true
  validates :message_type, presence: true
  validates :direction, inclusion: { in: %w[incoming outgoing] }

  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :unread, -> { where(read_at: nil) }

  def incoming?
    direction == "incoming"
  end

  def outgoing?
    direction == "outgoing"
  end

  def read?
    read_at.present?
  end

  def conversation_key
    phone_number.to_s.gsub(/\D/, "")
  end
end