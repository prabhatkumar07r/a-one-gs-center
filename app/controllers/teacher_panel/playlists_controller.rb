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

  def index
    normalize_positions
    @playlists = @course.playlists.order(:position, :id)
  end

  def show
  end

  def new
    @playlist = @course.playlists.new
  end

  def create
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

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to teacher_panel_course_playlists_path(@course),
                  notice: "Playlist updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playlist.destroy

    normalize_positions

    redirect_to teacher_panel_course_playlists_path(@course),
                notice: "Playlist deleted successfully."
  end

  private

  def set_course
    @course = Course.find(params[:course_id])
  end

  def set_playlist
    @playlist = @course.playlists.find(params[:id])
  end

  def playlist_params
    params.require(:playlist).permit(
      :title,
      :description
    )
  end

  def normalize_positions
  @course.playlists
         .order(Arel.sql("position ASC NULLS LAST"), :id)
         .each_with_index do |playlist, index|

    desired_position = index + 1

    if playlist.position != desired_position
      playlist.update_column(:position, desired_position)
    end

  end
end

  def teacher_or_admin
    unless current_user.teacher? || current_user.admin?
      redirect_to root_path,
                  alert: "Access Denied"
    end
  end

end