class QuizAnswer < ApplicationRecord
  belongs_to :quiz_attempt
  belongs_to :question
  belongs_to :option, optional: true

  validates :marks_obtained,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :question_id,
            uniqueness: {
              scope: :quiz_attempt_id
            }
end