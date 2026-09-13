class EbookPurchase < ApplicationRecord
  belongs_to :ebook
  belongs_to :user

  validates :amount,
            numericality: { greater_than_or_equal_to: 0 }

  scope :paid, -> {
    where(payment_status: "paid", status: "active")
  }

  def paid?
    payment_status == "paid" && status == "active"
  end
end