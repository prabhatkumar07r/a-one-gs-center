class TeacherPanel::VideosController < ApplicationController

  before_action :authenticate_user!
  before_action :require_teacher
    before_action :set_teacher_course


  layout "teacher"

  before_action :set_course
  before_action :set_video, only: [:show, :edit, :update, :destroy]


  def index
    @videos = @course.videos.order(position: :asc)
  end


  def show
  end
  def edit

  @playlists = @course.playlists.order(:position)

end

  def new
    @video = @course.videos.new
    @playlists = @course.playlists
  end


 def create

  @video = @course.videos.new(video_params)

  if @video.save

    redirect_to teacher_panel_course_videos_path(@course),
    notice: "Video added successfully."

  else

    @playlists = @course.playlists

    render :new,
    status: :unprocessable_entity

  end

end


def update

  if @video.update(video_params)

    redirect_to teacher_panel_course_videos_path(@course),
    notice: "Video updated successfully."

  else

    @playlists = @course.playlists

    render :edit,
    status: :unprocessable_entity

  end

end


def destroy

  @video.destroy

  redirect_to teacher_panel_course_videos_path(@course),
  notice: "Video deleted successfully."

end



  private



  def set_video

    @video = @course.videos.find(params[:id])

  end



  def video_params

    params.require(:video).permit(
      :title,
      :description,
      :video_url,
      :duration,
      :position,
      :playlist_id,
      :status,
      :thumbnail
    )

  end



  def require_teacher

    unless current_user.teacher? || current_user.admin?

      redirect_to root_path,
      alert: "Access Denied"

    end

  end

def set_course
  @course = Course.find(params[:course_id])
end
end