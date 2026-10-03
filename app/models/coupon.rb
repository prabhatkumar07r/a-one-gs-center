class Coupon < ApplicationRecord
  belongs_to :course, optional: true
  belongs_to :test_series, optional: true
  belongs_to :ebook, optional: true

  belongs_to :student,
             class_name: "User",
             optional: true

  has_many :coupon_usages,
           dependent: :restrict_with_error

  APPLICABLE_TO = %w[
    all
    courses
    test_series
    ebooks
  ].freeze

  before_validation :normalize_code
  before_validation :set_default_applicable_to

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

  validates :applicable_to,
            inclusion: { in: APPLICABLE_TO }

  validate :personal_coupon_requires_student
  validate :percentage_cannot_exceed_100
  validate :course_required_only_for_course_coupon
  validate :test_series_target_allowed
  validate :ebook_required_only_for_ebook_coupon

  scope :active_now, -> {
    where(active: true)
      .where("expires_at IS NULL OR expires_at >= ?", Time.current)
  }

  def personal?
    coupon_type == "personal"
  end

  def everyone?
    coupon_type == "everyone"
  end

  def applicable_to_all?
    applicable_to == "all"
  end

  def applicable_to_courses?
    applicable_to.in?(%w[all courses])
  end

  def applicable_to_test_series?
    applicable_to.in?(%w[all test_series])
  end

  def applicable_to_ebooks?
    applicable_to.in?(%w[all ebooks])
  end

  # Checks whether this coupon can be used for
  # the supplied Course, TestSeries or Ebook.
  def applicable_to?(product)
    return false unless product.present?

    case product
    when Course
      applicable_to_courses? &&
        (
          applicable_to_all? ||
          course_id.blank? ||
          course_id == product.id
        )

    when TestSeries
      applicable_to_test_series? &&
        (
          applicable_to_all? ||
          test_series_id.blank? ||
          test_series_id == product.id
        )

    when Ebook
      applicable_to_ebooks? &&
        (
          applicable_to_all? ||
          ebook_id.blank? ||
          ebook_id == product.id
        )

    else
      false
    end
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

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

  def available_for_user?(user)
    return false unless user.present?
    return false unless usable?
    return false if already_used_by?(user)

    personal? ? student_id == user.id : true
  end

  def already_used_by?(user)
    coupon_usages.exists?(user_id: user.id)
  end

  def discount_for(price)
    price = price.to_d

    discount =
      if discount_type == "percentage"
        price * discount_value.to_d / 100
      else
        discount_value.to_d
      end

    [discount, price].min
  end

  def final_price(price)
    price.to_d - discount_for(price)
  end

  private

  def set_default_applicable_to
    self.applicable_to = "courses" if applicable_to.blank?
  end

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def personal_coupon_requires_student
    if personal? && student_id.blank?
      errors.add(
        :student,
        "must be selected for a personal coupon"
      )
    end
  end

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

  def course_required_only_for_course_coupon
    return if applicable_to == "courses"

    if course_id.present?
      errors.add(
        :course,
        "cannot be selected for this coupon type"
      )
    end
  end

  def test_series_target_allowed
    return if applicable_to == "test_series"

    if test_series_id.present?
      errors.add(
        :test_series,
        "cannot be selected for this coupon type"
      )
    end
  end

  def ebook_required_only_for_ebook_coupon
    return if applicable_to == "ebooks"

    if ebook_id.present?
      errors.add(
        :ebook,
        "cannot be selected for this coupon type"
      )
    end
  end
end
