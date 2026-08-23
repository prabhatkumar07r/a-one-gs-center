class Payment < ApplicationRecord
  belongs_to :enrollment

  validates :amount, presence: true
  validates :status, presence: true

  def paid?
    status.to_s == "paid"
  end
end