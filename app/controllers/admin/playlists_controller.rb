module Admin
  class PlaylistsController < ApplicationController
        layout "admin"

    before_action :authenticate_user!
    before_action :require_admin

    before_action :set_course
    before_action :set_playlist, only: [:show, :edit, :update, :destroy]

    layout "admin"

    def index
      @playlists = @course.playlists.order(:position)
    end

    def show
    end

    def new
      @playlist = @course.playlists.new
    end

    def create
      @playlist = @course.playlists.new(playlist_params)

      if @playlist.save
        redirect_to admin_course_playlists_path(@course),
                    notice: "Playlist created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @playlist.update(playlist_params)
        redirect_to admin_course_playlists_path(@course),
                    notice: "Playlist updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @playlist.destroy

      redirect_to admin_course_playlists_path(@course),
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
        :description,
        :position
      )
    end
  end
end