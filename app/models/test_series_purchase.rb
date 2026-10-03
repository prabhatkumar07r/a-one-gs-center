class TestSeriesPurchase < ApplicationRecord
  belongs_to :user
  belongs_to :test_series

  belongs_to :coupon,
             optional: true

  has_one :coupon_usage,
          as: :purchasable,
          dependent: :nullify

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

  def test_series_price
    test_series.price.to_d
  end

  def original_price
    self[:original_amount].presence || test_series_price
  end

  def coupon_discount
    self[:discount_amount].to_d
  end

  def payable_amount
    self[:final_amount].presence || amount.to_d
  end

  def apply_coupon!(coupon)
    unless coupon.available_for_user?(user)
      errors.add(:coupon, "is not available for this student")
      raise ActiveRecord::RecordInvalid.new(self)
    end

    unless coupon.applicable_to?(test_series)
      errors.add(:coupon, "is not valid for this test series")
      raise ActiveRecord::RecordInvalid.new(self)
    end

    base_price = test_series_price
    discount = coupon.discount_for(base_price)
    final_price = base_price - discount

    update!(
      coupon: coupon,
      original_amount: base_price,
      discount_amount: discount,
      final_amount: final_price,
      amount: final_price
    )
  end

  def remove_coupon!
    price = test_series_price

    update!(
      coupon: nil,
      original_amount: price,
      discount_amount: 0,
      final_amount: price,
      amount: price
    )
  end
end
