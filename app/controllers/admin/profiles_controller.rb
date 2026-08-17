class Admin::ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  def show
    @admin = current_user
  end

  def edit
    @admin = current_user
  end

  def update
    @admin = current_user

    if @admin.update(admin_params)
      redirect_to admin_profile_path,
                  notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end

  def admin_params
    params.require(:user).permit(
      :name,
      :email,
      :mobile,
      :image
    )
  end
end