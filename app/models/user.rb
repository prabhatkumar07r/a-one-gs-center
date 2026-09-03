class User < ApplicationRecord

  # ================= DEVise =================

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]

  # ================= ASSOCIATIONS =================

  has_one :teacher
  has_one_attached :image
  has_many :quiz_attempts,
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

        # Google already verifies the email
        u.skip_confirmation!
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

  def confirmation_required?
  return false if teacher? || admin?

  super
end

  private

  def set_default_role
    self.role ||= "student"
  end

end