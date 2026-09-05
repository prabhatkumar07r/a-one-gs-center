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

  url = video_url.to_s.strip

  # Raw YouTube video ID
  return url if url.match?(/\A[A-Za-z0-9_-]{11}\z/)

  # Standard YouTube URL
  if url.include?("youtu.be/")
    url.split("youtu.be/").last.split(/[?&#]/).first
  elsif url.include?("/shorts/")
    url.split("/shorts/").last.split(/[?&#]/).first
  elsif url.include?("watch?v=")
    url.split("watch?v=").last.split(/[&#]/).first
  elsif url.include?("/embed/")
    url.split("/embed/").last.split(/[?&#]/).first
  elsif url.include?("/live/")
    url.split("/live/").last.split(/[?&#]/).first
  end
end

  def youtube_thumbnail
    return unless youtube_id

    "https://img.youtube.com/vi/#{youtube_id}/hqdefault.jpg"
  end
end