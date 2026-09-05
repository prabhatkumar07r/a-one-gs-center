class Option < ApplicationRecord
  belongs_to :question
has_many :quiz_answers,
         dependent: :destroy
  validates :option_text,
            presence: true

  validates :position,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }
end