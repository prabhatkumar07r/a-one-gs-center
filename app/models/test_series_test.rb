class TestSeriesTest < ApplicationRecord

  belongs_to :test_series

  has_many :test_series_questions,
           -> { order(position: :asc) },
           dependent: :destroy

  validates :title, presence: true

  validates :test_number,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }
  has_many :test_series_attempts,
           dependent: :destroy
  validates :duration,
            numericality: {
              only_integer: true,
              greater_than: 0
            },
            allow_nil: true

  validates :status,
            presence: true

  scope :active, -> {
    where(status: "Active")
  }

  def calculated_total_marks

    test_series_questions.sum(:marks).to_f

  end

  def question_count
  test_series_questions.count
end


  def calculated_total_questions

    test_series_questions.count

  end

end