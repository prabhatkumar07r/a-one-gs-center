class Resource < ApplicationRecord
  belongs_to :playlist

  has_one_attached :file, dependent: :purge_later

  enum :resource_type, {
    pdf: 0,
    assignment: 1,
    ppt: 2,
    zip_file: 3
  }

  validates :title, presence: true
  validates :resource_type, presence: true
  validates :file, presence: true
end