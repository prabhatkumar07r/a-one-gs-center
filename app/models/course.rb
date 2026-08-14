class Course < ApplicationRecord
  belongs_to :teacher

  has_many :enrollments, dependent: :destroy
  has_many :students,
           through: :enrollments,
           source: :user

  has_one_attached :image

  has_many :attendances
  has_many :videos, dependent: :destroy
  has_many :batches
  has_many :playlists, dependent: :destroy

  # Study Notes
  has_many :notes, through: :playlists

  # Resources
  has_many :resources, through: :playlists

  has_many :certificates, dependent: :destroy

  validates :Course_name, :duration, :fee, presence: true



  def discount_percentage
  return 0 if original_fee.blank? || original_fee.to_f <= 0

  (((original_fee - fee) / original_fee.to_f) * 100).round
end
end