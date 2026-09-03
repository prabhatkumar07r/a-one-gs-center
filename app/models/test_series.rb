class TestSeries < ApplicationRecord

  # ==================================================
  # ASSOCIATIONS
  # ==================================================

  has_many :test_series_tests,
           dependent: :destroy

  has_many :test_series_purchases,
           dependent: :destroy

  has_many :users,
           through: :test_series_purchases

  has_many :quizzes,
           dependent: :nullify

  has_one_attached :image


  # ==================================================
  # VALIDATIONS
  # ==================================================

  validates :title,
            presence: true

  validates :exam_name,
            presence: true

  validates :mode,
            presence: true

  validates :language,
            presence: true

  validates :price,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :original_price,
            numericality: {
              greater_than_or_equal_to: 0
            },
            allow_nil: true

  validates :discount,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            },
            allow_nil: true


  # ==================================================
  # SCOPES
  # ==================================================

  scope :active, -> {
    where(status: "Active")
  }

  scope :online, -> {
    where(mode: "Online")
  }

  scope :offline, -> {
    where(mode: "Offline")
  }


  # ==================================================
  # TEST SERIES STATISTICS
  # ==================================================

  def test_count
    test_series_tests.count
  end

  def question_count
    test_series_tests
      .joins(:test_series_questions)
      .count("test_series_questions.id")
  end
  
def total_questions
  question_count
end

  def total_marks
    test_series_tests
      .joins(:test_series_questions)
      .sum("test_series_questions.marks")
  end


  # ==================================================
  # HELPERS
  # ==================================================

  def free?
    price.to_d.zero?
  end

  def premium?
    !free?
  end

  def discounted?
    discount.to_i > 0
  end

  def final_price
    price.to_d
  end
before_validation :calculate_discount

private

def calculate_discount
  original = original_price.to_d
  selling  = price.to_d

  self.discount =
    if original > 0 && selling >= 0 && selling <= original
      (((original - selling) / original) * 100).round
    else
      0
    end
end

end