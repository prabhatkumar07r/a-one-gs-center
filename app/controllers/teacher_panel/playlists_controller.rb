class TeacherPanel::PlaylistsController < ApplicationController

  before_action :authenticate_user!
  before_action :teacher_or_admin
  before_action :set_course
  before_action :set_playlist, only: [
    :show,
    :edit,
    :update,
    :destroy
  ]

  layout "teacher"

  # =========================================================
  # PLAYLIST LIST
  # =========================================================

  def index
    normalize_positions

    @playlists = @course.playlists.order(:position, :id)
  end

  # =========================================================
  # PLAYLIST SHOW
  # =========================================================

  def show
  end

  # =========================================================
  # NEW
  # =========================================================

  def new
    @playlist = @course.playlists.new
  end

  # =========================================================
  # CREATE
  # =========================================================

  def create
    normalize_positions

    @playlist = @course.playlists.new(playlist_params)

    @playlist.position =
      (@course.playlists.maximum(:position) || 0) + 1

    if @playlist.save
      redirect_to teacher_panel_course_playlists_path(@course),
                  notice: "Playlist created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # =========================================================
  # EDIT
  # =========================================================

  def edit
  end

  # =========================================================
  # UPDATE
  # =========================================================

  def update
    if @playlist.update(playlist_params)
      redirect_to teacher_panel_course_playlists_path(@course),
                  notice: "Playlist updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # =========================================================
  # DELETE
  # =========================================================

  def destroy
    @playlist.destroy

    normalize_positions

    redirect_to teacher_panel_course_playlists_path(@course),
                notice: "Playlist deleted successfully."
  end

  private

  # =========================================================
  # COURSE ACCESS
  # =========================================================

  def set_course
    if current_user.admin?
      @course = Course.find(params[:course_id])
    else
      @course = current_user.teacher.courses.find(params[:course_id])
    end
  end

  # =========================================================
  # PLAYLIST ACCESS
  # =========================================================

  def set_playlist
    @playlist = @course.playlists.find(params[:id])
  end

  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def playlist_params
    params.require(:playlist).permit(
      :title,
      :description
    )
  end

  # =========================================================
  # AUTO NORMALIZE POSITIONS
  # =========================================================

  def normalize_positions
    @course.playlists
           .order(
             Arel.sql("position ASC NULLS LAST"),
             :id
           )
           .each_with_index do |playlist, index|

      desired_position = index + 1

      if playlist.position != desired_position
        playlist.update_column(
          :position,
          desired_position
        )
      end

    end
  end

  # =========================================================
  # ROLE CHECK
  # =========================================================

  def teacher_or_admin
    unless current_user.teacher? || current_user.admin?
      redirect_to root_path,
                  alert: "Access Denied"
    end
  end

end