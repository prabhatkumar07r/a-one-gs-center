class Note < ApplicationRecord

  belongs_to :playlist
  belongs_to :user, optional:true
   belongs_to :video

  has_one_attached :pdf_file


  validates :title, presence: true


  validate :acceptable_file,
  if: -> { pdf_file.attached? }


  scope :recent, -> {
    order(created_at: :desc)
  }



  private



  
  def video_belongs_to_playlist

    return if video.blank? || playlist.blank?

    unless video.playlist_id == playlist.id

      errors.add(
        :video,
        "must belong to the selected playlist"
      )

    end

  end


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