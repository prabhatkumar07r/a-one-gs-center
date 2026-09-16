class ResourcesController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :require_admin

  before_action :set_course
  before_action :set_playlist

  before_action :set_resource,
                only: [:show, :edit, :update, :destroy]

  # GET /courses/:course_id/playlists/:playlist_id/resources
  def index
    @resources = @playlist.resources
                           .order(created_at: :desc)
  end

  # GET /courses/:course_id/playlists/:playlist_id/resources/new
  def new
    @resource = @playlist.resources.build
  end

  # POST /courses/:course_id/playlists/:playlist_id/resources
  def create
    @resource = @playlist.resources.build(resource_params)

    if @resource.save
      redirect_to course_playlist_resources_path(
        @course,
        @playlist
      ),
      notice: "Resource added successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  # GET /courses/:course_id/playlists/:playlist_id/resources/:id
  def show
  end

  # GET /courses/:course_id/playlists/:playlist_id/resources/:id/edit
  def edit
  end

  # PATCH/PUT
  def update
    if @resource.update(resource_params)
      redirect_to course_playlist_resources_path(
        @course,
        @playlist
      ),
      notice: "Resource updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  # DELETE
  def destroy
    @resource.destroy

    redirect_to course_playlist_resources_path(
      @course,
      @playlist
    ),
    notice: "Resource deleted successfully."
  end

  private

  def set_course
    @course = Course.find(params[:course_id])
  end

  def set_playlist
    @playlist = @course.playlists.find(params[:playlist_id])
  end

  def set_resource
    @resource = @playlist.resources.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(
      :title,
      :description,
      :resource_type,
      :file
    )
  end
end