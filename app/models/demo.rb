class Demo < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  validates :name, presence: true

  validates :phone,
            presence: true,
            length: { is: 10 },
            format: { with: /\A[0-9]{10}\z/, message: "must be 10 digits" }

  validates :email,
            presence: true,
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              message: "is invalid"
            }

  validates :course, presence: true
  validates :batch, presence: true

  before_create :set_default_status

  private

  def set_default_status
    self.status = "Pending" if status.blank?
  end
end