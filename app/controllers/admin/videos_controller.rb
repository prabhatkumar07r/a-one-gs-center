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
                          .order(:position)
      else
        @videos = @course.videos
                          .order(:position)
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

        @playlist = @course.playlists.find(
          params[:playlist_id]
        )

        @video = @playlist.videos.new

      else

        @video = @course.videos.new

      end

      @playlists = @course.playlists.order(:position)
    end


    # =========================================================
    # CREATE
    # =========================================================

    def create

      @playlists = @course.playlists.order(:position)

      if video_params[:playlist_id].present?

        @playlist = @course.playlists.find(
          video_params[:playlist_id]
        )

        @video = @playlist.videos.new(video_params)

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

        render :new,
               status: :unprocessable_entity

      end
    end


    # =========================================================
    # EDIT
    # =========================================================

    def edit

      @playlist = @video.playlist

      @playlists = @course.playlists
                           .order(:position)

    end


    # =========================================================
    # UPDATE
    # =========================================================

    def update

      if @video.update(video_params)

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
                             .order(:position)

        render :edit,
               status: :unprocessable_entity

      end
    end


    # =========================================================
    # DESTROY
    # =========================================================

    def destroy

      playlist = @video.playlist

      @video.destroy


      if playlist.present?

        redirect_to admin_course_playlist_videos_path(
          @course,
          playlist
        ),
        notice: "Video deleted successfully.",
        status: :see_other

      else

        redirect_to admin_course_playlists_path(
          @course
        ),
        notice: "Video deleted successfully.",
        status: :see_other

      end
    end


    private


    # =========================================================
    # COURSE
    # =========================================================

    def set_course

      @course = Course.find(
        params[:course_id]
      )

    end


    # =========================================================
    # VIDEO
    # =========================================================

    def set_video

      @video = @course.videos.find(
        params[:id]
      )

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
        :position,
        :status,
        :video_url,
        :thumbnail,
        :playlist_id
      )

    end

  end
end