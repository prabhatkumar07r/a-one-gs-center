class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :course

  belongs_to :coupon,
             optional: true

  has_one :coupon_usage,
          as: :purchasable,
          dependent: :nullify

  has_many :payments,
           dependent: :destroy

  has_one :fee,
          dependent: :destroy

  validates :status,
            presence: true

  attribute :status,
            default: "Pending"

  def course_price
    course.fee.to_d
  end

  def course_discount_amount
    fee&.discount_amount.to_d
  end

  def price_after_course_discount
    amount =
      course_price - course_discount_amount

    amount = 0 if amount < 0

    amount
  end

  def apply_coupon!(coupon)
    unless coupon.available_for_user?(user)
      errors.add(
        :coupon,
        "is not available for this student"
      )

      raise ActiveRecord::RecordInvalid.new(self)
    end

    unless coupon.applicable_to?(course)
      errors.add(
        :coupon,
        "is not valid for this course"
      )

      raise ActiveRecord::RecordInvalid.new(self)
    end

    coupon_base_price =
      price_after_course_discount

    discount =
      coupon.discount_for(coupon_base_price)

    update!(
      coupon: coupon,
      original_amount: course_price,
      discount_amount: discount,
      final_amount: coupon_base_price - discount
    )
  end

  def remove_coupon!
    update!(
      coupon: nil,
      original_amount: course_price,
      discount_amount: 0,
      final_amount: price_after_course_discount
    )
  end

  def payable_amount
    if coupon.present?
      final_amount.to_d
    else
      price_after_course_discount
    end
  end

  def display_name
    "#{user.name} - #{course.Course_name}"
  end
end
