class Note < ApplicationRecord

  belongs_to :playlist
  belongs_to :user, optional:true
   belongs_to :video, optional: true

  has_one_attached :pdf_file


  validates :title, presence: true


  validate :acceptable_file,
  if: -> { pdf_file.attached? }


  scope :recent, -> {
    order(created_at: :desc)
  }



  private


  def acceptable_file

    return unless pdf_file.attached?


    unless pdf_file.content_type == "application/pdf"

      errors.add(
        :pdf_file,
        "must be PDF"
      )

    end


    if pdf_file.byte_size > 10.megabytes

      errors.add(
        :pdf_file,
        "must be less than 10MB"
      )

    end

  end


end