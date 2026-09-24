class User < ApplicationRecord

  # ================= DEVise =================

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]

  # ================= ASSOCIATIONS =================

  has_one :teacher
  has_one_attached :image
  has_many :quiz_attempts,
         dependent: :destroy
  has_many :coupon_usages,
         dependent: :destroy

has_many :personal_coupons,
         class_name: "Coupon",
         foreign_key: :student_id,
         dependent: :nullify


has_many :ai_conversations,
         class_name: "Ai::Conversation",
         dependent: :destroy

has_many :ai_support_requests,
         class_name: "Ai::SupportRequest",
         dependent: :destroy

has_many :admin_ai_support_requests,
         class_name: "Ai::SupportRequest",
         foreign_key: :admin_user_id,
         dependent: :nullify
  has_many :ai_support_messages,
         class_name: "Ai::SupportMessage",
         dependent: :destroy                               

  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :video_progresses, dependent: :destroy
  has_many :certificates, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :test_series_purchases, dependent: :destroy
  has_many :purchased_test_series,
         through: :test_series_purchases,
         source: :test_series
  has_many :test_series_attempts, dependent: :destroy
has_many :test_series_answers, through: :test_series_attempts
has_many :ebook_purchases, dependent: :restrict_with_error
  # ================= GOOGLE LOGIN =================

  def self.from_omniauth(auth)

    user = where(email: auth.info.email).first

    if user
      user
    else
      create do |u|
        u.email = auth.info.email
        u.name = auth.info.name
        u.password = Devise.friendly_token[0, 20]

     end
    end

  end

  # ================= DEFAULT ROLE =================

  after_initialize :set_default_role, if: :new_record?

  # ================= ROLES =================

  enum :role, {
    student: "student",
    teacher: "teacher",
    admin: "admin"
  }

  validates :role, presence: true

  

  private

  def set_default_role
    self.role ||= "student"
  end

end