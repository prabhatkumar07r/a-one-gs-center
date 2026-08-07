class ResourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resource, only: :show

  def index
    @resources = Resource.includes(:playlist)
                         .order(created_at: :desc)
  end

  def show
  end

  private

  def set_resource
    @resource = Resource.find(params[:id])
  end
end