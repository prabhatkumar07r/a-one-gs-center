class Coupon < ApplicationRecord
  belongs_to :course

  belongs_to :student,
             class_name: "User",
             optional: true

  has_many :coupon_usages,
           dependent: :restrict_with_error

  before_validation :normalize_code

  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false }

  validates :coupon_type,
            inclusion: { in: %w[everyone personal] }

  validates :discount_type,
            inclusion: { in: %w[percentage fixed] }

  validates :discount_value,
            numericality: { greater_than: 0 }

  validates :usage_limit,
            numericality: {
              only_integer: true,
              greater_than: 0
            },
            allow_nil: true

  validates :used_count,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  validate :personal_coupon_requires_student
  validate :percentage_cannot_exceed_100

  scope :active_now, -> {
    where(active: true)
      .where("expires_at IS NULL OR expires_at >= ?", Time.current)
  }

  # ==================================================
  # COUPON TYPE
  # ==================================================

  def personal?
    coupon_type == "personal"
  end

  def everyone?
    coupon_type == "everyone"
  end

  # ==================================================
  # STATUS
  # ==================================================

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # Personal coupon is ALWAYS one-time.
  #
  # Everyone coupon follows its usage_limit.
  # Example:
  # usage_limit = 100
  # => maximum 100 successful uses
  # ==================================================

  def usage_exhausted?
    if personal?
      used_count >= 1
    else
      usage_limit.present? && used_count >= usage_limit
    end
  end

  def usable?
    active? &&
      !expired? &&
      !usage_exhausted?
  end

  # ==================================================
  # USER ELIGIBILITY
  # ==================================================

  def available_for_user?(user)
    return false unless user.present?
    return false unless usable?

    # Same student cannot use the same coupon twice.
    return false if already_used_by?(user)

    # Personal coupon:
    # only the assigned student can use it.
    if personal?
      student_id == user.id
    else
      # Everyone coupon:
      # any authenticated student can use it once.
      true
    end
  end

  # ==================================================
  # ALREADY USED?
  # ==================================================

  def already_used_by?(user)
    coupon_usages.exists?(user_id: user.id)
  end

  # ==================================================
  # DISCOUNT CALCULATION
  # ==================================================

  def discount_for(price)
    price = price.to_d

    discount =
      if discount_type == "percentage"
        price * discount_value.to_d / 100
      else
        discount_value.to_d
      end

    # Never allow discount greater than course price.
    [discount, price].min
  end

  # ==================================================
  # FINAL PRICE
  # ==================================================

  def final_price(price)
    price.to_d - discount_for(price)
  end

  private

  # ==================================================
  # NORMALIZE COUPON CODE
  # ==================================================

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  # ==================================================
  # PERSONAL COUPON MUST HAVE A STUDENT
  # ==================================================

  def personal_coupon_requires_student
    if personal? && student_id.blank?
      errors.add(
        :student,
        "must be selected for a personal coupon"
      )
    end
  end

  # ==================================================
  # PERCENTAGE LIMIT
  # ==================================================

  def percentage_cannot_exceed_100
    if discount_type == "percentage" &&
       discount_value.present? &&
       discount_value > 100

      errors.add(
        :discount_value,
        "cannot be greater than 100%"
      )
    end
  end
end