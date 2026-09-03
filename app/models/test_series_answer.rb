class TestSeriesAnswer < ApplicationRecord

  # ==================================================
  # ASSOCIATIONS
  # ==================================================

  belongs_to :test_series_attempt

  belongs_to :test_series_question

  belongs_to :test_series_option


  # ==================================================
  # VALIDATIONS
  # ==================================================

  validates :is_correct,
            inclusion: {
              in: [true, false]
            }

  validates :marks_obtained,
            numericality: {
              greater_than_or_equal_to: 0
            }


  # ==================================================
  # SCOPES
  # ==================================================

  scope :correct, -> {
    where(is_correct: true)
  }

  scope :incorrect, -> {
    where(is_correct: false)
  }

end