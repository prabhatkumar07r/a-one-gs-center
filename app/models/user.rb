class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]
   has_one :teacher    
  has_one_attached :image   


  def self.from_omniauth(auth)

    user = where(email: auth.info.email).first

    if user
      user
    else
      create do |u|
        u.email = auth.info.email
        u.name = auth.info.name
        u.password = Devise.friendly_token[0,20]
      end
    end

  end

  # Associations
  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :video_progresses, dependent: :destroy
  has_many :certificates, dependent: :destroy
    has_many :notes, dependent: :destroy

  # Default role
  after_initialize :set_default_role, if: :new_record?

  # Roles
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