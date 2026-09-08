class TeacherPanel::VideosController < ApplicationController

  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_course
  before_action :set_video, only: [:show, :edit, :update, :destroy]

  layout "teacher"

  # =========================================================
  # INDEX
  # =========================================================

  def index
    @videos = @course.videos.order(:position, :id)
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
  end

  # =========================================================
  # NEW
  # =========================================================

  def new
    @video = @course.videos.new
    @playlists = @course.playlists.order(:position, :id)
  end

  # =========================================================
  # EDIT
  # =========================================================

  def edit
    @playlists = @course.playlists.order(:position, :id)
  end

  # =========================================================
  # CREATE
  # =========================================================

  def create
    @playlists = @course.playlists.order(:position, :id)

    playlist_id = video_params[:playlist_id]

    if playlist_id.present?

      @playlist = @course.playlists.find(playlist_id)

      @video = @playlist.videos.new(video_params)
      @video.course = @course

      # Always assign next position automatically
      @video.position =
        (@playlist.videos.maximum(:position) || 0) + 1

    else

      @video = @course.videos.new(video_params)

    end

    if @video.save

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video added successfully."

    else

      render :new,
             status: :unprocessable_entity

    end
  end

  # =========================================================
  # UPDATE
  # =========================================================

  def update
    old_playlist = @video.playlist

    new_playlist =
      if video_params[:playlist_id].present?
        @course.playlists.find(video_params[:playlist_id])
      else
        nil
      end

    playlist_changed =
      old_playlist&.id != new_playlist&.id

    # =======================================================
    # MOVING VIDEO TO ANOTHER PLAYLIST
    # =======================================================

    if playlist_changed

      @video.playlist = new_playlist

      if new_playlist.present?

        @video.position =
          (
            new_playlist
              .videos
              .where.not(id: @video.id)
              .maximum(:position) || 0
          ) + 1

      else

        @video.position = nil

      end

    end

    if @video.update(video_params)

      # Renumber old playlist
      if playlist_changed && old_playlist.present?
        renumber_videos(old_playlist)
      end

      # Renumber new playlist
      if playlist_changed && new_playlist.present?
        renumber_videos(new_playlist)
      end

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video updated successfully."

    else

      @playlists = @course.playlists.order(:position, :id)

      render :edit,
             status: :unprocessable_entity

    end
  end

  # =========================================================
  # DESTROY
  # =========================================================

  def destroy
    playlist = @video.playlist

    if @video.destroy

      # Re-number remaining videos
      if playlist.present?
        renumber_videos(playlist)
      end

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video deleted successfully."

    else

      redirect_to teacher_panel_course_videos_path(@course),
                  alert: "Video could not be deleted."

    end
  end

  private

  # =========================================================
  # RENUMBER VIDEOS
  # =========================================================

  def renumber_videos(playlist)

    playlist
      .videos
      .order(:position, :id)
      .each_with_index do |video, index|

      new_position = index + 1

      if video.position != new_position
        video.update_column(:position, new_position)
      end

    end

  end

  # =========================================================
  # SET COURSE
  # =========================================================

  def set_course
    @course = Course.find(params[:course_id])
  end

  # =========================================================
  # SET VIDEO
  # =========================================================

  def set_video
    @video = @course.videos.find(params[:id])
  end

  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def video_params
    params.require(:video).permit(
      :title,
      :description,
      :video_url,
      :duration,
      :playlist_id,
      :status,
      :thumbnail,
      :is_free
    )
  end

  # =========================================================
  # TEACHER / ADMIN ACCESS
  # =========================================================

  def require_teacher
    unless current_user.teacher? || current_user.admin?

      redirect_to root_path,
                  alert: "Access Denied"

    end
  end

end