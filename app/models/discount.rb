class Discount < ApplicationRecord
  has_many :course_discounts, dependent: :destroy
  has_many :courses, through: :course_discounts

  validates :name, presence: true

  validates :discount_type,
            presence: true,
            inclusion: {
              in: %w[percentage fixed]
            }

  validates :discount_value,
            presence: true,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :start_date, presence: true
  validates :end_date, presence: true

  validates :status,
            inclusion: {
              in: %w[Active Inactive]
            }

  validate :end_date_after_start_date

  scope :active, -> {
    where(status: "Active")
      .where("start_date <= ? AND end_date >= ?", Date.current, Date.current)
  }

  def percentage?
    discount_type == "percentage"
  end

  def fixed?
    discount_type == "fixed"
  end

  def calculate_discount(amount)
    amount = amount.to_d

    return 0.to_d if discount_value.blank?

    if percentage?
      (amount * discount_value.to_d / 100).round(2)
    else
      [discount_value.to_d, amount].min
    end
  end

  def final_amount(amount)
    amount = amount.to_d

    discount = calculate_discount(amount)

    [amount - discount, 0.to_d].max
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end