class Achievement < ApplicationRecord

  has_one_attached :photo
  has_one_attached :video

  validates :title,
            presence: true,
            length: { maximum: 150 }

  validates :student_name,
            length: { maximum: 100 },
            allow_blank: true

  validates :rank,
            length: { maximum: 150 },
            allow_blank: true

  validates :description,
            length: { maximum: 500 },
            allow_blank: true

  scope :active, -> {
    where(status: "Active")
  }

end