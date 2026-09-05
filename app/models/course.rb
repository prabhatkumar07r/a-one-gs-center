class Course < ApplicationRecord
  belongs_to :teacher

  has_many :enrollments, dependent: :destroy

  has_many :students,
           through: :enrollments,
           source: :user

  has_one_attached :image
  has_many :quizzes, dependent: :destroy

  # ==========================================
  # DISCOUNTS
  # ==========================================

  has_many :course_discounts,
           dependent: :destroy

  has_many :discounts,
           through: :course_discounts

  # ==========================================
  # COURSE CONTENT
  # ==========================================

  has_many :attendances, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :batches, dependent: :destroy
  has_many :playlists, dependent: :destroy

  has_many :notes, through: :playlists
  has_many :resources, through: :playlists

  has_many :certificates, dependent: :destroy

  # ==========================================
  # VALIDATIONS
  # ==========================================

  validates :Course_name,
            :duration,
            :fee,
            presence: true

  # ==========================================
  # FREE / PAID
  # ==========================================

  def free?
    fee.to_d.zero?
  end

  def paid?
    fee.to_d.positive?
  end

  # ==========================================
  # ACTIVE DISCOUNT
  # ==========================================

  def active_discount
    discounts
      .active
      .order(created_at: :desc)
      .first
  end

  # ==========================================
  # DISCOUNTED FEE
  # ==========================================

  def discounted_fee
    discount = active_discount

    return fee.to_d unless discount

    discount.final_amount(fee)
  end

  # ==========================================
  # DISCOUNT AMOUNT
  # ==========================================

  def discount_amount
    fee.to_d - discounted_fee
  end

  # ==========================================
  # DISCOUNT PERCENTAGE
  # ==========================================

  def discount_percentage
    return 0 if original_fee.blank? || fee.blank?
    return 0 if original_fee.to_d <= 0
    return 0 if original_fee.to_d <= fee.to_d

    (((original_fee.to_d - fee.to_d) / original_fee.to_d) * 100).round
  end

  # ==========================================
  # HELPER METHODS
  # ==========================================

  def current_discount_amount
    discount_amount
  end

  def final_fee
    discounted_fee
  end

  def has_active_discount?
    active_discount.present?
  end

  def discounted?
    has_active_discount? && discounted_fee < fee.to_d
  end
end