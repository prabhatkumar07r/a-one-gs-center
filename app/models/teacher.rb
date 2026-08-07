class Teacher < ApplicationRecord

  belongs_to :user

  has_many :courses, dependent: :nullify

  has_one_attached :photo

  validates :name, presence: true
  validates :email, presence: true
  validates :mobile, presence: true
  validates :subject, presence: true

end