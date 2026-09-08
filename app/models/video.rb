require "uri"

class Video < ApplicationRecord
  belongs_to :course
  belongs_to :playlist
  has_many :quizzes, dependent: :destroy

  has_many :notes, dependent: :destroy

  scope :free, -> { where(is_free: true) }
  scope :paid, -> { where(is_free: false) }

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


  # =========================================================
  # YOUTUBE VIDEO ID
  # =========================================================

  def youtube_id
    return if video_url.blank?

    value = video_url.to_s.strip

    # -------------------------------------------------------
    # Raw YouTube ID
    # Example:
    # 595LwEjPNNA
    # -------------------------------------------------------

    return value if value.match?(/\A[A-Za-z0-9_-]{11}\z/)


    begin
      uri = URI.parse(value)

      host = uri.host.to_s.downcase
      path = uri.path.to_s


      # -----------------------------------------------------
      # youtu.be
      #
      # https://youtu.be/595LwEjPNNA
      # -----------------------------------------------------

      if host == "youtu.be" ||
         host == "www.youtu.be"

        return path.split("/").reject(&:blank?).first
      end


      # -----------------------------------------------------
      # youtube.com
      # -----------------------------------------------------

      if host == "youtube.com" ||
         host == "www.youtube.com" ||
         host == "m.youtube.com"

        # -----------------------------------------------
        # https://www.youtube.com/watch?v=595LwEjPNNA
        # -----------------------------------------------

        if path == "/watch"

          params =
            Rack::Utils.parse_nested_query(
              uri.query.to_s
            )

          return params["v"].to_s.strip.presence
        end


        # -----------------------------------------------
        # https://www.youtube.com/shorts/595LwEjPNNA
        # -----------------------------------------------

        if path.start_with?("/shorts/")

          return path
            .split("/")
            .reject(&:blank?)[1]
            .to_s
            .strip
            .presence

        end


        # -----------------------------------------------
        # https://www.youtube.com/embed/595LwEjPNNA
        # -----------------------------------------------

        if path.start_with?("/embed/")

          return path
            .split("/")
            .reject(&:blank?)[1]
            .to_s
            .strip
            .presence

        end


        # -----------------------------------------------
        # https://www.youtube.com/live/595LwEjPNNA
        # -----------------------------------------------

        if path.start_with?("/live/")

          return path
            .split("/")
            .reject(&:blank?)[1]
            .to_s
            .strip
            .presence

        end

      end

    rescue URI::InvalidURIError
      return nil
    end


    nil
  end


  # =========================================================
  # YOUTUBE THUMBNAIL
  # =========================================================

  def youtube_thumbnail
    id = youtube_id

    return if id.blank?

    "https://img.youtube.com/vi/#{id}/hqdefault.jpg"
  end

end