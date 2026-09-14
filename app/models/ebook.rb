class Ebook < ApplicationRecord
  has_one_attached :cover_image
  has_one_attached :pdf_file
 has_many :ebook_purchases, dependent: :restrict_with_error
  before_validation :calculate_discount

  validates :title, presence: true
  has_many :ebook_files,
         -> { order(:position, :id) },
         dependent: :destroy

  validates :price,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :original_price,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :discount_percentage,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }

  scope :published, -> { where(status: "published") }
  scope :free, -> { where(is_free: true) }
  scope :paid, -> { where(is_free: false) }
  


  def free?
    is_free?
  end

  def paid?
    !is_free?
  end

  private

  def calculate_discount
    if is_free?
      self.price = 0
      self.original_price = 0
      self.discount_percentage = 0
      return
    end

    original = original_price.to_f
    selling = price.to_f

    if original > 0 && selling >= 0 && selling <= original
      self.discount_percentage =
        (((original - selling) / original) * 100).round
    else
      self.discount_percentage = 0
    end
  end
end