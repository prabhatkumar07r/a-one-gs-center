
class Admin::BannersController < ApplicationController
  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_banner, only: %i[edit update destroy toggle_status]

  def index
    @banners = Banner.order(:position, :id)
  end

  def new
    @banner = Banner.new(position: 0, active: true)
  end

  def create
    @banner = Banner.new(banner_params)

    if @banner.save
      redirect_to admin_banners_path, notice: "Banner created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @banner.update(banner_params)
      redirect_to admin_banners_path, notice: "Banner updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @banner.destroy
    redirect_to admin_banners_path, notice: "Banner deleted successfully."
  end

  def toggle_status
    @banner.update!(active: !@banner.active?)
    redirect_to admin_banners_path, notice: "Banner status updated."
  end

  private

  def set_banner
    @banner = Banner.find(params[:id])
  end

  def banner_params
    params.require(:banner).permit(
      :title,
      :subtitle,
      :button_text,
      :button_url,
      :position,
      :active,
      :image
    )
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path,
                  alert: "You are not authorized to access this page."
    end
  end
end
