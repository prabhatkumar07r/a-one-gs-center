class Quiz < ApplicationRecord
  belongs_to :course
  belongs_to :video, optional: true
  belongs_to :test_series, optional: true

  has_many :questions, dependent: :destroy
  has_many :quiz_attempts, dependent: :destroy

  validates :title, presence: true

  validates :time_limit,
            presence: true,
            numericality: { greater_than: 0 }

  validates :passing_percentage,
            presence: true,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }

  validates :status, presence: true

  scope :active, -> {
    where(status: "Active")
  }

  scope :course_wise, -> {
    where(video_id: nil)
  }

  scope :video_wise, -> {
    where.not(video_id: nil)
  }

  validate :video_belongs_to_course

  private

  def video_belongs_to_course
    return if video.blank?

    if video.course_id != course_id
      errors.add(:video, "must belong to the selected course")
    end
  end
end