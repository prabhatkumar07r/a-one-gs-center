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
    @videos = @course.videos.order(position: :asc)
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
    @playlists = @course.playlists.order(:position)
  end


  # =========================================================
  # EDIT
  # =========================================================

  def edit
    @playlists = @course.playlists.order(:position)
  end


  # =========================================================
  # CREATE
  # =========================================================

  def create

    @video = @course.videos.new(video_params)

    if @video.save

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video added successfully."

    else

      @playlists = @course.playlists.order(:position)

      render :new,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # UPDATE
  # =========================================================

  def update

    if @video.update(video_params)

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video updated successfully."

    else

      @playlists = @course.playlists.order(:position)

      render :edit,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # DESTROY
  # =========================================================

  def destroy

    if @video.destroy

      redirect_to teacher_panel_course_videos_path(@course),
                  notice: "Video deleted successfully."

    else

      redirect_to teacher_panel_course_videos_path(@course),
                  alert: "Video could not be deleted."

    end

  end


  private


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
      :position,
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