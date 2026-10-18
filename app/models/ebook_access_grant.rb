class EbookAccessGrant < ApplicationRecord
  belongs_to :user
  belongs_to :ebook

  belongs_to :granted_by,
             class_name: "User",
             foreign_key: :granted_by_id

  validates :reason, presence: true

  scope :active, -> {
    where(revoked_at: nil)
  }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end