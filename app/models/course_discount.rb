class CourseDiscount < ApplicationRecord
  belongs_to :course
  belongs_to :discount

  validates :course_id,
            uniqueness: {
              scope: :discount_id
            }
end