module Admin
  class VideosController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin

    before_action :set_course
    before_action :set_video, only: [:show, :edit, :update, :destroy]

    # =========================================================
    # INDEX
    # =========================================================

    def index
      if params[:playlist_id].present?
        @playlist = @course.playlists.find(params[:playlist_id])

        @videos = @playlist.videos
                          .order(:position, :id)
      else
        @videos = @course.videos
                          .order(:position, :id)
      end
    end

    # =========================================================
    # SHOW
    # =========================================================

    def show
      @playlist = @video.playlist
    end

    # =========================================================
    # NEW
    # =========================================================

    def new
      if params[:playlist_id].present?
        @playlist = @course.playlists.find(params[:playlist_id])

        @video = @playlist.videos.new

        @video.position =
          (@playlist.videos.maximum(:position) || 0) + 1
      else
        @video = @course.videos.new
      end

      @playlists = @course.playlists.order(:position, :id)
    end

    # =========================================================
    # CREATE
    # =========================================================

    def create
      @playlists = @course.playlists.order(:position, :id)

      if video_params[:playlist_id].present?
        @playlist = @course.playlists.find(video_params[:playlist_id])

        @video = @playlist.videos.new(video_params)
        @video.course = @course

        if @video.position.blank?
          @video.position =
            (@playlist.videos.maximum(:position) || 0) + 1
        end
      else
        @video = @course.videos.new(video_params)
      end

      if @video.save
        if @video.playlist.present?
          redirect_to admin_course_playlist_video_path(
            @course,
            @video.playlist,
            @video
          ),
          notice: "Video added successfully."
        else
          redirect_to admin_course_playlists_path(@course),
                      notice: "Video added successfully, but no playlist was assigned."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    # =========================================================
    # EDIT
    # =========================================================

    def edit
      @playlist = @video.playlist

      @playlists = @course.playlists
                           .order(:position, :id)
    end

    # =========================================================
    # UPDATE
    # =========================================================

    def update
      old_playlist = @video.playlist

      new_playlist =
        if video_params[:playlist_id].present?
          @course.playlists.find(video_params[:playlist_id])
        end

      playlist_changed =
        old_playlist&.id != new_playlist&.id

      # -------------------------------------------------------
      # Moving video to another playlist
      # -------------------------------------------------------

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

        # -----------------------------------------------------
        # Renumber OLD playlist
        # -----------------------------------------------------

        if playlist_changed && old_playlist.present?
          renumber_videos(old_playlist)
        end

        # -----------------------------------------------------
        # Renumber NEW playlist
        # -----------------------------------------------------

        if playlist_changed && new_playlist.present?
          renumber_videos(new_playlist)
        end

        # -----------------------------------------------------
        # Redirect
        # -----------------------------------------------------

        if @video.playlist.present?
          redirect_to admin_course_playlist_video_path(
            @course,
            @video.playlist,
            @video
          ),
          notice: "Video updated successfully."
        else
          redirect_to admin_course_playlists_path(@course),
                      notice: "Video updated successfully."
        end

      else
        @playlist = @video.playlist

        @playlists = @course.playlists
                             .order(:position, :id)

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

        # -----------------------------------------------------
        # Renumber remaining videos
        # -----------------------------------------------------

        if playlist.present?
          renumber_videos(playlist)

          redirect_to admin_course_playlist_videos_path(
            @course,
            playlist
          ),
          notice: "Video deleted successfully.",
          status: :see_other
        else

          redirect_to admin_course_playlists_path(@course),
                      notice: "Video deleted successfully.",
                      status: :see_other
        end

      else

        redirect_to admin_course_playlists_path(@course),
                    alert: "Unable to delete video.",
                    status: :see_other
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
          video.update!(position: new_position)
        end
      end
    end

    # =========================================================
    # COURSE
    # =========================================================

    def set_course
      @course = Course.find(params[:course_id])
    end

    # =========================================================
    # VIDEO
    # =========================================================

    def set_video
      @video = @course.videos.find(params[:id])
      @playlist = @video.playlist
    end

    # =========================================================
    # STRONG PARAMETERS
    # =========================================================

    def video_params
      params.require(:video).permit(
        :title,
        :description,
        :duration,
        :status,
        :video_url,
        :thumbnail,
        :playlist_id
      )
    end
  end
end