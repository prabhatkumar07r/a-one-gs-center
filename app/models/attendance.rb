class Attendance < ApplicationRecord
  belongs_to :user
  belongs_to :course
  validates :date, presence: true
  validates :status, presence: true
  validates :date, uniqueness: {
    scope: [:user_id, :course_id],
    message: "Attendance already marked for this date."
  }
end
