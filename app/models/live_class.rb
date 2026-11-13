class LiveClass < ApplicationRecord
  belongs_to :course
  belongs_to :playlist, optional: true

  # ==========================================
  # VALIDATIONS
  # ==========================================

  validates :title, presence: true

  validates :access_type,
            presence: true,
            inclusion: {
              in: %w[free enrolled]
            }

  validates :status,
            presence: true,
            inclusion: {
              in: %w[upcoming live ended]
            }

  validates :provider,
            presence: true,
            inclusion: {
              in: %w[youtube]
            }

  # Stream URL is required only when admin
  # manually sets the class to LIVE.
  validates :stream_url,
            presence: true,
            if: :stream_url_required?

  validate :valid_youtube_stream_url
  validate :valid_youtube_recording_url

  # ==========================================
  # ACCESS TYPES
  # ==========================================

  def free?
    access_type == "free"
  end

  def enrolled_only?
    access_type == "enrolled"
  end

  # ==========================================
  # STATUS SYSTEM
  # ==========================================

  # Admin has enabled manual control.
  def manual_status?
    self[:manual_status] == true
  end

  # Final status used throughout the student side.
  #
  # Automatic mode:
  #   Before scheduled_at → upcoming
  #   During duration     → live
  #   After duration      → ended
  #
  # Manual mode:
  #   Use the status selected by admin.
  def effective_status
    return status if manual_status?
    return status if scheduled_at.blank?

    # If duration is missing or invalid, we cannot
    # safely calculate an end time.
    return "upcoming" if duration.blank? || duration.to_i <= 0 &&
                         Time.current < scheduled_at

    return "live" if duration.blank? || duration.to_i <= 0

    end_time = scheduled_at + duration.to_i.minutes

    if Time.current < scheduled_at
      "upcoming"
    elsif Time.current < end_time
      "live"
    else
      "ended"
    end
  end

  def upcoming?
    effective_status == "upcoming"
  end

  def live?
    effective_status == "live"
  end

  def ended?
    effective_status == "ended"
  end

  # ==========================================
  # YOUTUBE EMBED URL
  # ==========================================

  def embed_stream_url
    youtube_embed_url(stream_url)
  end

  def embed_recording_url
    youtube_embed_url(recording_url)
  end

  private

  # ==========================================
  # STREAM URL VALIDATION
  # ==========================================

  def stream_url_required?
    manual_status? && status == "live"
  end
# ==========================================
# CONVERT YOUTUBE URL TO EMBED URL
# ==========================================

def youtube_embed_url(url)
  return nil if url.blank?

  video_id = extract_youtube_video_id(url)
  return nil if video_id.blank?

  "https://www.youtube.com/embed/#{video_id}"
end


# ==========================================
# EXTRACT YOUTUBE VIDEO ID
# ==========================================

def extract_youtube_video_id(url)
  return nil if url.blank?

  patterns = [
    %r{youtu\.be/([^?&/]+)},
    %r{youtube\.com/live/([^?&/]+)},
    %r{youtube\.com/watch\?v=([^?&/]+)},
    %r{youtube\.com/embed/([^?&/]+)}
  ]

  patterns.each do |pattern|
    match = url.match(pattern)
    return match[1] if match
  end

  nil
end

  # ==========================================
  # VALIDATE STREAM URL
  # ==========================================

  def valid_youtube_stream_url
    return if stream_url.blank?
    return if extract_youtube_video_id(stream_url).present?

    errors.add(
      :stream_url,
      "must be a valid YouTube URL"
    )
  end

  # ==========================================
  # VALIDATE RECORDING URL
  # ==========================================

  def valid_youtube_recording_url
    return if recording_url.blank?
    return if extract_youtube_video_id(recording_url).present?

    errors.add(
      :recording_url,
      "must be a valid YouTube URL"
    )
  end
end