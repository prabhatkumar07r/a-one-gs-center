class Enrollment < ApplicationRecord

  belongs_to :user
  belongs_to :course
  

  # Payments
  has_many :payments, dependent: :destroy

  # Fee
  has_one :fee, dependent: :destroy

  validates :status, presence: true

  attribute :status, default: "Pending"

  def display_name
    "#{user.name} - #{course.Course_name}"
  end

end