class Gallery < ApplicationRecord
	 has_many_attached :photos
     validates :title, presence: true
     validates :category, presence: true
end
