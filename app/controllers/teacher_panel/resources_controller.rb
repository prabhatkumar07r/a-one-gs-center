class TeacherPanel::ResourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_teacher_course


  layout "teacher"
  before_action :set_resource, only: [:show, :edit, :update, :destroy]

  def index
    @resources = @course.resources.includes(:playlist)
  end

  def show
  end

  def new
    @resource = Resource.new
    @playlists = @course.playlists.order(:position)
  end

  def create
    @resource = Resource.new(resource_params)

    if @resource.save
      redirect_to teacher_panel_course_resources_path(@course),
                  notice: "Resource uploaded successfully."
    else
      @playlists = @course.playlists.order(:position)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @playlists = @course.playlists.order(:position)
  end

  def update
    if @resource.update(resource_params)
      redirect_to teacher_panel_course_resources_path(@course),
                  notice: "Resource updated successfully."
    else
      @playlists = @course.playlists.order(:position)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy

    redirect_to teacher_panel_course_resources_path(@course),
                notice: "Resource deleted successfully."
  end

  private

  def set_resource
    @resource = @course.resources.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(
      :title,
      :description,
      :playlist_id,
      :resource_type,
      :file
    )
  end

  def require_teacher
  unless current_user.teacher?
    redirect_to root_path,
                alert: "Access Denied"
  end
end
def set_course
  @course = Course.find(params[:course_id])
end
end