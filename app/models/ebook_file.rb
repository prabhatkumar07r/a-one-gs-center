class EbookFile < ApplicationRecord
  belongs_to :ebook

  has_one_attached :pdf

  validates :title,
            presence: true,
            length: { maximum: 255 }

  validates :position,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validates :status,
            presence: true,
            inclusion: {
              in: %w[active inactive]
            }

  validate :pdf_must_be_pdf

  scope :active,
        -> { where(status: "active").order(:position, :id) }

  before_validation :set_position,
                    on: :create

  private

  def set_position
    return if position.present? && position.to_i > 0

    self.position =
      ebook&.ebook_files&.maximum(:position).to_i + 1
  end

  def pdf_must_be_pdf
    return unless pdf.attached?

    unless pdf.content_type == "application/pdf"
      errors.add(:pdf, "must be a PDF file")
    end
  end
end