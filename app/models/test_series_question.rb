class TestSeriesQuestion < ApplicationRecord

  # ==================================================
  # ASSOCIATIONS
  # ==================================================

  belongs_to :test_series_test

  has_many :test_series_options,
           dependent: :destroy
has_many :test_series_answers,
         dependent: :destroy         


 accepts_nested_attributes_for :test_series_options,
                                allow_destroy: true

  # ==================================================
  # VALIDATIONS
  # ==================================================
  validates :question_text, presence: true
  validates :question_text,
            presence: true

  validates :question_type,
            presence: true

  validates :marks,
            numericality: {
              greater_than: 0
            }

  validates :position,
            numericality: {
              only_integer: true,
              greater_than: 0
            }


  # ==================================================
  # SCOPES
  # ==================================================

  scope :ordered, -> {
    order(position: :asc)
  }


  # ==================================================
  # HELPERS
  # ==================================================

  def correct_option
    test_series_options.find_by(is_correct: true)
  end

  
  # ==========================================
  # LANGUAGE HELPERS
  # ==========================================

  def question_for(language)
    if language.to_s == "hi"
      question_text_hindi.presence || question_text
    else
      question_text
    end
  end

  def explanation_for(language)
    if language.to_s == "hi"
      explanation_hindi.presence || explanation
    else
      explanation
    end
  end

end