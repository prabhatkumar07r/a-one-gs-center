class TestSeriesAttempt < ApplicationRecord

  # =========================================================
  # ASSOCIATIONS
  # =========================================================

  belongs_to :user
  belongs_to :test_series_test

  has_many :test_series_answers,
           dependent: :destroy

  has_many :test_series_attempt_questions,
           dependent: :destroy

  # =========================================================
  # SCOPES
  # =========================================================

  scope :in_progress, -> {
    where(status: "In Progress")
  }

  scope :completed, -> {
    where(status: "Completed")
  }

  # =========================================================
  # HELPERS
  # =========================================================

  def completed?
    status.to_s == "Completed"
  end

  def in_progress?
    status.to_s == "In Progress"
  end

end