class Enrollment < ApplicationRecord

  belongs_to :user
  belongs_to :course
  has_many :payments
   has_one :fee, dependent: :destroy

  has_one :fee

  validates :status, presence: true

  attribute :status, default: "Pending"


  def display_name
    "#{user.name} - #{course.Course_name}"
  end

end