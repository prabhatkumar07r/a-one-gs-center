class CouponUsage < ApplicationRecord
  belongs_to :coupon
  belongs_to :user
  belongs_to :enrollment

  validates :discount_amount,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :used_at,
            presence: true

  validates :user_id,
            uniqueness: {
              scope: :coupon_id,
              message: "has already used this coupon"
            }
end