class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :teacher_or_admin

  before_action :set_course
  before_action :set_playlist, only: [:show, :edit, :update, :destroy]

  def index
    @playlists = @course.playlists
  end

  def show
  end

  def new
    @playlist = @course.playlists.new
  end

  def create
    @playlist = @course.playlists.new(playlist_params)

    if @playlist.save
      redirect_to course_playlists_path(@course),
                  notice: "Playlist created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to course_playlists_path(@course),
                  notice: "Playlist updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playlist.destroy

    redirect_to course_playlists_path(@course),
                notice: "Playlist deleted successfully."
  end

  private

  def teacher_or_admin
    unless current_user.admin? || current_user.teacher?
      redirect_to root_path, alert: "Access Denied"
    end
  end

  def set_course
    @course = Course.find(params[:course_id])
  end

  def set_playlist
    @playlist = @course.playlists.find(params[:id])
  end

  def playlist_params
    params.require(:playlist).permit(
      :title,
      :description,
      :position
    )
  end
end