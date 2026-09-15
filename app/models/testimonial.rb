class Testimonial < ApplicationRecord

  has_one_attached :student_photo
  has_one_attached :video

  scope :active, -> {
    where(status: "Active")
  }

  scope :ordered, -> {
    order(:display_order, :created_at)
  }

  validates :student_name, presence: true
  validates :message, presence: true

  validates :rating,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            },
            allow_nil: true

end