class Gallery < ApplicationRecord

  # =========================================================
  # ACTIVE STORAGE
  # =========================================================

  has_many_attached :photos


  # =========================================================
  # GALLERY CATEGORIES
  # =========================================================

  ALLOWED_CATEGORIES = %w[
    classes
    events
    achievements
    results
    students
    faculty
    study
    other
  ].freeze


  # =========================================================
  # VALIDATIONS
  # =========================================================

  validates :categories,
            presence: true

  validate :valid_gallery_categories


  private


  # =========================================================
  # CATEGORY VALIDATION
  # =========================================================

  def valid_gallery_categories
    invalid_categories =
      categories.to_a - ALLOWED_CATEGORIES

    if invalid_categories.any?
      errors.add(
        :categories,
        "contains invalid categories"
      )
    end
  end

end