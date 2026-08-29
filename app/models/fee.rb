class Fee < ApplicationRecord
  belongs_to :enrollment

  # ==========================================
  # VALIDATIONS
  # ==========================================

  validates :total_fee,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :paid_amount,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :discount_amount,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :due_amount,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  # One fee record per enrollment
  validates :enrollment_id,
            uniqueness: true

  # ==========================================
  # CALLBACKS
  # ==========================================

  before_validation :set_fee_details
  before_validation :calculate_due_amount
  before_validation :calculate_status

  private

  # ==========================================
  # SET FEE + DISCOUNT
  # ==========================================

  def set_fee_details
    return unless enrollment&.course

    course = enrollment.course

    # Original course fee
    self.total_fee = course.fee.to_d if total_fee.blank?

    # Default paid amount
    self.paid_amount ||= 0

    # Default discount
    self.discount_amount ||= 0

    # Apply active discount only when this
    # Fee does not already have a discount.
    if discount_amount.zero? && course.has_active_discount?
      discount = course.active_discount

      self.discount_amount =
        discount.calculate_discount(course.fee)

      self.discount_name =
        discount.name
    end
  end

  # ==========================================
  # CALCULATE DUE
  # ==========================================

  def calculate_due_amount
    payable_amount =
      total_fee.to_d - discount_amount.to_d

    payable_amount = 0 if payable_amount < 0

    self.due_amount =
      payable_amount - paid_amount.to_d

    self.due_amount = 0 if self.due_amount < 0
  end

  # ==========================================
  # CALCULATE STATUS
  # ==========================================

  def calculate_status
    payable_amount =
      total_fee.to_d - discount_amount.to_d

    payable_amount = 0 if payable_amount < 0

    if paid_amount.to_d >= payable_amount
      self.status = "Paid"

    elsif paid_amount.to_d > 0
      self.status = "Partial"

    else
      self.status = "Due"
    end
  end
end