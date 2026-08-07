class Achievement < ApplicationRecord
	
	has_one_attached :photo

  validates :title, :description, presence: true
end
 