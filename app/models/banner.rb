
class Banner < ApplicationRecord
  has_one_attached :image

  validates :title, presence: true
  validates :position, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0
  }

  scope :active, -> { where(active: true).order(:position, :id) }

  validate :image_must_be_an_image

  private

  def image_must_be_an_image
    return unless image.attached?

    unless image.blob.content_type&.start_with?("image/")
      errors.add(:image, "must be an image")
    end
  end
end