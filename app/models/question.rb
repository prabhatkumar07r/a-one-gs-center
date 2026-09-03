class Question < ApplicationRecord
  belongs_to :quiz

  has_many :options,
           class_name: "Option",
           dependent: :destroy

  accepts_nested_attributes_for :options,
                                allow_destroy: true

  validates :question_text, presence: true

  validates :marks,
            presence: true,
            numericality: { greater_than: 0 }

  validates :position,
            presence: true,
            numericality: { greater_than: 0 }

  validate :exactly_one_correct_option

  private

  def exactly_one_correct_option
    correct_count = options.count { |option| option.is_correct? }

    unless correct_count == 1
      errors.add(
        :options,
        "must have exactly one correct answer"
      )
    end
  end
end