class Enrollment < ApplicationRecord

  belongs_to :user
  belongs_to :course

  belongs_to :coupon,
             optional: true

  # Payments
  has_many :payments, dependent: :destroy

  # Fee
  has_one :fee, dependent: :destroy

  validates :status, presence: true

  attribute :status, default: "Pending"

  # ==================================================
  # BASE COURSE PRICE
  # ==================================================

  def course_price
    course.fee.to_d
  end

  # ==================================================
  # EXISTING COURSE/FEE DISCOUNT
  # ==================================================

  def course_discount_amount
    fee&.discount_amount.to_d
  end

  # ==================================================
  # PRICE AFTER EXISTING COURSE DISCOUNT
  # ==================================================

  def price_after_course_discount
    amount = course_price - course_discount_amount

    amount = 0 if amount < 0

    amount
  end

  # ==================================================
  # APPLY COUPON
  # ==================================================

  def apply_coupon!(coupon)

    unless coupon.available_for_user?(user)
      raise ActiveRecord::RecordInvalid,
            "Coupon is not available for this student."
    end

    unless coupon.course_id == course_id
      raise ActiveRecord::RecordInvalid,
            "This coupon is not valid for this course."
    end

    coupon_base_price = price_after_course_discount

    discount = coupon.discount_for(coupon_base_price)

    update!(
      coupon: coupon,
      original_amount: course_price,
      discount_amount: discount,
      final_amount: coupon_base_price - discount
    )
  end

  # ==================================================
  # REMOVE COUPON
  # ==================================================

  def remove_coupon!

    update!(
      coupon: nil,
      original_amount: course_price,
      discount_amount: 0,
      final_amount: price_after_course_discount
    )
  end

  # ==================================================
  # FINAL PAYABLE AMOUNT
  # ==================================================

  def payable_amount

    if coupon.present?
      final_amount.to_d
    else
      price_after_course_discount
    end

  end

  # ==================================================
  # DISPLAY NAME
  # ==================================================

  def display_name
    "#{user.name} - #{course.Course_name}"
  end

end