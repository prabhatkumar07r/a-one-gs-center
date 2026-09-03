class TestSeriesPurchase < ApplicationRecord
  belongs_to :user
  belongs_to :test_series

  validates :user, presence: true
  validates :test_series, presence: true

  validates :amount,
            numericality: { greater_than_or_equal_to: 0 }

  validates :status,
            presence: true

  validates :payment_status,
            presence: true

  scope :paid, -> {
    where(payment_status: "paid", status: "Active")
  }

  def paid?
    payment_status.to_s.downcase == "paid" &&
      status.to_s.downcase == "active"
  end
end