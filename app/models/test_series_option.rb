class TestSeriesOption < ApplicationRecord

  # ==================================================
  # ASSOCIATIONS
  # ==================================================

  belongs_to :test_series_question
  has_many :test_series_answers,
         dependent: :destroy

  # ==================================================
  # VALIDATIONS
  # ==================================================

  validates :option_text,
            presence: true

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



    # ==========================================
  # LANGUAGE HELPER
  # ==========================================

  def text_for(language)
    if language.to_s == "hi"
      option_text_hindi.presence || option_text
    else
      option_text
    end
  end

end