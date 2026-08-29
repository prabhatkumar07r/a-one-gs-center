class FeePayment < ApplicationRecord
  belongs_to :fee

  validates :amount,
            presence: true,
            numericality: { greater_than: 0 }

  validates :payment_mode,
            presence: true

  validates :payment_date,
            presence: true
end