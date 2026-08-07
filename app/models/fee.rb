class Fee < ApplicationRecord
  belongs_to :enrollment

  validates :total_fee, presence: true
  validates :paid_amount, presence: true
end
