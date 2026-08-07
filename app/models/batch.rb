class Batch < ApplicationRecord
  belongs_to :course
  belongs_to :teacher

  has_many :batch_students, dependent: :destroy
  has_many :students, through: :batch_students
end