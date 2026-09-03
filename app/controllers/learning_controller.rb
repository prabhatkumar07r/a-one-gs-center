class LearningController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course, only: [:show, :video, :complete_video]

  # =========================================================
  # COURSE LIST
  # =========================================================

  def index
    @courses = Course.where(status: "Active")
  end


  # =========================================================
  # COURSE LEARNING PAGE
  # =========================================================

  def show
    @course = Course.find(params[:id])

    # =======================================================
    # PLAYLISTS
    # =======================================================

    @playlists = @course.playlists
                        .includes(
                          :videos,
                          :notes,
                          :resources
                        )
                        .order(:position)


    # =======================================================
    # STUDY NOTES
    # =======================================================

    @notes = Note.joins(:playlist)
                 .where(
                   playlists: {
                     course_id: @course.id
                   }
                 )


    # =======================================================
    # RESOURCES
    # =======================================================

    @resources = Resource.joins(:playlist)
                         .where(
                           playlists: {
                             course_id: @course.id
                           }
                         )


    # =======================================================
    # QUIZZES
    # =======================================================

    @quizzes = @course.quizzes
                      .where(status: "Active")
                      .includes(:questions)
                      .order(created_at: :desc)


    # =======================================================
    # COURSE PROGRESS
    # =======================================================

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


    @progress =
      if @total_videos.zero?
        0
      else
        ((@completed_videos.to_f / @total_videos) * 100).round
      end


    # Your view uses @progress
    @course_progress = @progress


    # =======================================================
    # CERTIFICATE
    # =======================================================

    @certificate = Certificate.find_by(
      user: current_user,
      course: @course
    )
  end


  # =========================================================
  # VIDEO
  # =========================================================

  def video
    @video = @course.videos.find(params[:id])

    @playlist = @video.playlist


    # =======================================================
    # PLAYLISTS
    # =======================================================

    @playlists = @course.playlists
                        .includes(
                          :videos,
                          :resources,
                          :notes
                        )
                        .order(:position)


    # =======================================================
    # UNLOCKED PLAYLISTS
    # =======================================================

    @unlocked_playlist_ids = unlocked_playlists


    # =======================================================
    # STUDY NOTES
    # =======================================================

    @notes = @playlist.notes
                      .order(created_at: :desc)


    # =======================================================
    # RESOURCES
    # =======================================================

    @resources = @playlist.resources
                         .order(created_at: :desc)


    # =======================================================
    # OVERALL COURSE PROGRESS
    # =======================================================

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
      end


    # =======================================================
    # CERTIFICATE
    # =======================================================

    @certificate = Certificate.find_by(
      user: current_user,
      course: @course
    )


    # =======================================================
    # PREVIOUS / NEXT VIDEO
    # =======================================================

    videos = @course.videos
                    .order(:position)
                    .to_a

    current_index = videos.index(@video)


    @previous_video =
      if current_index&.positive?
        videos[current_index - 1]
      else
        nil
      end


    @next_video =
      if current_index && current_index < videos.size - 1
        videos[current_index + 1]
      else
        nil
      end
  end


  # =========================================================
  # COMPLETE VIDEO
  # =========================================================

  def complete_video
    @video = @course.videos.find(params[:id])


    # =======================================================
    # SAVE VIDEO PROGRESS
    # =======================================================

    progress =
      current_user.video_progresses
                  .find_or_initialize_by(video: @video)

    progress.completed = true
    progress.last_watched_at = Time.current
    progress.save!


    # =======================================================
    # GENERATE CERTIFICATE
    # =======================================================

    generate_certificate(@course)


    # =======================================================
    # CURRENT PLAYLIST VIDEOS
    # =======================================================

    playlist_videos =
      @video.playlist.videos
            .order(:position)
            .to_a

    current_index = playlist_videos.index(@video)


    # =======================================================
    # NEXT VIDEO IN SAME PLAYLIST
    # =======================================================

    if current_index &&
       current_index < playlist_videos.size - 1

      next_video = playlist_videos[current_index + 1]

      redirect_to learning_video_path(
        @course,
        next_video
      ),
      notice: "✅ Video completed!"

      return
    end


    # =======================================================
    # CURRENT PLAYLIST COMPLETED
    # =======================================================

    next_playlist =
      @course.playlists
             .where(
               "position > ?",
               @video.playlist.position
             )
             .order(:position)
             .first


    # =======================================================
    # START NEXT PLAYLIST
    # =======================================================

    if next_playlist.present? &&
       next_playlist.videos.any?

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


  # =========================================================
  # PRIVATE
  # =========================================================

  private


  # =========================================================
  # SET COURSE
  # =========================================================

  def set_course
    @course =
      if params[:course_id].present?
        Course.find(params[:course_id])
      else
        Course.find(params[:id])
      end
  end


  # =========================================================
  # PLAYLIST ACCESS
  # =========================================================

  def check_playlist_access
    @video = @course.videos.find(params[:id])

    playlist = @video.playlist

    unlocked_ids = unlocked_playlists

    unless unlocked_ids.include?(playlist.id)

      redirect_to learning_course_path(@course),
                  alert: "Complete previous playlist first."

    end
  end


  # =========================================================
  # GENERATE CERTIFICATE
  # =========================================================

  def generate_certificate(course)

    total = course.videos.count


    completed =
      current_user.video_progresses
                  .joins(:video)
                  .where(
                    videos: {
                      course_id: course.id
                    },
                    completed: true
                  )
                  .count


    return unless total.positive?

    return unless completed == total


    Certificate.find_or_create_by!(
      user: current_user,
      course: course
    ) do |certificate|

      certificate.issued_on = Date.current

    end
  end


  # =========================================================
  # UNLOCK PLAYLISTS ONE BY ONE
  # =========================================================

  def unlocked_playlists

    unlocked = []


    @playlists.each do |playlist|

      # First playlist is always unlocked
      unlocked << playlist.id


      total = playlist.videos.count


      completed =
        current_user.video_progresses
                    .joins(:video)
                    .where(
                      videos: {
                        playlist_id: playlist.id
                      },
                      completed: true
                    )
                    .count


      # Stop unlocking after the first incomplete playlist
      break unless completed == total

    end


    unlocked
  end

end