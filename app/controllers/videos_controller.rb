class VideosController < ApplicationController

  before_action :set_course
  before_action :set_video, only: [:show, :edit, :update, :destroy]


  def index
    if params[:playlist_id].present?
      @playlist = @course.playlists.find(params[:playlist_id])
      @videos = @playlist.videos.order(:position)
    else
      @videos = @course.videos.order(:position)
    end
  end


  def show
  end


  def new
  if params[:playlist_id].present?
    @playlist = @course.playlists.find(params[:playlist_id])
    @video = @playlist.videos.new
  else
    @video = @course.videos.new
  end

  @playlists = @course.playlists.order(:position)
end


def create
  @video = @course.videos.new(video_params)
  @playlists = @course.playlists.order(:position)

  if @video.save
    redirect_to course_playlist_video_path(
      @course,
      @video.playlist,
      @video
    ), notice: "Video added successfully."
  else
    render :new, status: :unprocessable_entity
  end
end

def edit
  @playlist = @video.playlist
  @playlists = @course.playlists.order(:position)
end


def update
  if @video.update(video_params)
    redirect_to course_playlist_video_path(
      @course,
      @video.playlist,
      @video
    ), notice: "Video updated successfully."
  else
    render :edit, status: :unprocessable_entity
  end
end


  def destroy
    @video.destroy

    redirect_to course_playlist_videos_path(
      @course,
      @video.playlist
    ),
    notice: "Video deleted successfully."
  end


  private


  def set_course
    @course = Course.find(params[:course_id])
  end


 def set_video
  @video = @course.videos.find(params[:id])
  @playlist = @video.playlist
end


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