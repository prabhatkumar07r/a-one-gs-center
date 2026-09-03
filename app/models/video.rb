class Video < ApplicationRecord
  belongs_to :course
  belongs_to :playlist
  has_many :quizzes, dependent: :destroy

  has_many :notes, dependent: :destroy

  has_one_attached :video_file
  has_one_attached :thumbnail

  has_many :video_progresses, dependent: :destroy

  enum :status, {
    inactive: 0,
    active: 1
  }

  validates :title, presence: true
  validates :position, presence: true
  validates :video_url, presence: true

  def youtube_id
    return if video_url.blank?

    if video_url.include?("youtu.be/")
      video_url.split("/").last.split("?").first
    elsif video_url.include?("/shorts/")
      video_url.split("/shorts/").last.split("?").first
    elsif video_url.include?("watch?v=")
      video_url.split("v=").last.split("&").first
    end
  end

  def youtube_thumbnail
    return unless youtube_id

    "https://img.youtube.com/vi/#{youtube_id}/hqdefault.jpg"
  end
end