
class LearningController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course, only: [:show, :video, :complete_video]
  
  


  def index
    @courses = Course.where(status: "Active")
  end
def show
  @course = Course.find(params[:id])

  @playlists = @course.playlists
                      .includes(:videos)

  @notes = Note.joins(:playlist)
               .where(playlists: { course_id: @course.id })

  @resources = Resource.joins(:playlist)
                             .where(playlists: { course_id: @course.id })
end

 def video
  @video = @course.videos.find(params[:id])

  @playlist = @video.playlist

  @playlists = @course.playlists
                      .includes(:videos, :resources, :notes)
                      .order(:position)

  @unlocked_playlist_ids = unlocked_playlists

  # Study Notes
  @notes = @playlist.notes.order(created_at: :desc)

  # Resources
  @resources = @playlist.resources.order(created_at: :desc)
  # ===============================
# Overall Course Progress
# ===============================

@total_videos = @course.videos.count

@completed_videos =
  current_user.video_progresses
              .joins(:video)
              .where(
                videos: {
                  course_id: @course.id
                },
                completed: true
              )
              .count

@course_progress =
  if @total_videos.zero?
    0
  else
    ((@completed_videos.to_f / @total_videos) * 100).round
    @certificate = Certificate.find_by(
  user: current_user,
  course: @course
)
  end


  videos = @course.videos.order(:position)

  current_index = videos.index(@video)

  @previous_video =
    current_index&.positive? ? videos[current_index - 1] : nil

  @next_video =
    current_index && current_index < videos.size - 1 ?
      videos[current_index + 1] :
      nil
end
 def complete_video
  @video = @course.videos.find(params[:id])

  progress = current_user.video_progresses.find_or_initialize_by(video: @video)

  progress.completed = true
  progress.last_watched_at = Time.current
  progress.save

  generate_certificate(@course)

  # Current playlist videos
  playlist_videos = @video.playlist.videos.order(:position).to_a

  current_index = playlist_videos.index(@video)

  # Next video inside current playlist
  if current_index && current_index < playlist_videos.size - 1

    next_video = playlist_videos[current_index + 1]

    redirect_to learning_video_path(@course, next_video),
                notice: "✅ Video completed!"

    return
  end

  # Current playlist finished
  next_playlist = @course.playlists
                         .where("position > ?", @video.playlist.position)
                         .order(:position)
                         .first

  if next_playlist.present? && next_playlist.videos.any?

    redirect_to learning_video_path(
      @course,
      next_playlist.videos.order(:position).first
    ),
    notice: "🎉 Playlist completed! Starting next playlist."

  else

    redirect_to learning_course_path(@course),
                notice: "🎉 Congratulations! Course Completed."

  end
end

    private




    def check_playlist_access
  @video = @course.videos.find(params[:id])

  playlist = @video.playlist

  unlocked_ids = unlocked_playlists

  unless unlocked_ids.include?(playlist.id)
    redirect_to learning_course_path(@course),
                alert: "Complete previous playlist first."
  end
end

  def set_course
    @course =
      if params[:course_id].present?
        Course.find(params[:course_id])
      else
        Course.find(params[:id])
      end
  end



  def generate_certificate(course)
    total = course.videos.count

    completed =
      current_user.video_progresses
                  .joins(:video)
                  .where(
                    videos: { course_id: course.id },
                    completed: true
                  )
                  .count

    return unless total.positive?
    return unless completed == total

    Certificate.find_or_create_by(
      user: current_user,
      course: course
    ) do |certificate|
      certificate.issued_on = Date.current
    end
  end

  # ===============================
  # Unlock Playlists One by One
  # ===============================
 def unlocked_playlists
  unlocked = []

  @playlists.each do |playlist|

    unlocked << playlist.id

    total = playlist.videos.count

    completed =
      current_user.video_progresses
                  .joins(:video)
                  .where(
                    videos: { playlist_id: playlist.id },
                    completed: true
                  )
                  .count

    break unless completed == total
  end

  unlocked
end
end