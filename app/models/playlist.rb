class Playlist < ApplicationRecord
  belongs_to :course

  has_many :videos, dependent: :nullify
  has_many :resources, dependent: :destroy
  has_many :notes, dependent: :destroy
  

  validates :title, presence: true

  default_scope { order(:position) }
end