class Notification < ApplicationRecord
  validates :title, :description, presence: true

  scope :active, -> {
    where(status: "Active")
      .where("start_date <= ?", Date.current)
      .where("end_date >= ? OR end_date IS NULL", Date.current)
      .order(created_at: :desc)
  }
end