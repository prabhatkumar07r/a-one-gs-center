class TestSeriesAttemptQuestion < ApplicationRecord
  belongs_to :test_series_attempt
  belongs_to :test_series_question

  validates :test_series_attempt_id,
            uniqueness: {
              scope: :test_series_question_id
            }
end