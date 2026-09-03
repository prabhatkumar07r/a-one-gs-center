class QuizAttempt < ApplicationRecord
  belongs_to :quiz
  belongs_to :user

  has_many :quiz_answers,
           dependent: :destroy

  validates :status,
            inclusion: {
              in: %w[in_progress submitted passed failed]
            }

  validates :score,
            numericality: { greater_than_or_equal_to: 0 }

  validates :total_marks,
            numericality: { greater_than_or_equal_to: 0 }

  validates :percentage,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }

  # ==========================================
  # STATUS HELPERS
  # ==========================================

  def in_progress?
    status == "in_progress"
  end

  def submitted?
    status == "submitted"
  end

  def passed?
    status == "passed"
  end

  def failed?
    status == "failed"
  end
end