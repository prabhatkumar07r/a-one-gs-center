class EbookPurchase < ApplicationRecord
  belongs_to :ebook
  belongs_to :user

  belongs_to :coupon,
             optional: true

  has_one :coupon_usage,
          as: :purchasable,
          dependent: :nullify

  validates :amount,
            numericality: {
              greater_than_or_equal_to: 0
            }

  scope :paid, -> {
    where(
      payment_status: "paid",
      status: "active"
    )
  }

  def paid?
    payment_status == "paid" &&
      status == "active"
  end

  # =========================================================
  # E-BOOK PRICE
  # =========================================================

  def ebook_price
    ebook.price.to_d
  end

  # =========================================================
  # ORIGINAL PRICE
  # =========================================================

  def original_price
    self[:original_amount].presence || ebook_price
  end

  # =========================================================
  # COUPON DISCOUNT
  # =========================================================

  def coupon_discount
    self[:discount_amount].to_d
  end

  # =========================================================
  # FINAL PAYABLE AMOUNT
  # =========================================================

  def payable_amount
    self[:final_amount].presence || amount.to_d
  end

  # =========================================================
  # APPLY COUPON
  # =========================================================

def apply_coupon!(coupon)
  unless coupon.available_for_user?(user)
    errors.add(:coupon, "is not available for this student")
    raise ActiveRecord::RecordInvalid.new(self)
  end

  unless coupon.applicable_to?(ebook)
    errors.add(:coupon, "is not valid for this E-Book")
    raise ActiveRecord::RecordInvalid.new(self)
  end

  base_price = ebook_price
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

  # =========================================================
  # REMOVE COUPON
  # =========================================================

  def remove_coupon!
    price = ebook_price

    update!(
      coupon: nil,
      original_amount: price,
      discount_amount: 0,
      final_amount: price,
      amount: price
    )
  end
end