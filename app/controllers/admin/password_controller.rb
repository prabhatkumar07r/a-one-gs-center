class Admin::PasswordController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  def edit
    @admin = current_user
  end

  def update
    @admin = current_user

    if @admin.update_with_password(password_params)
      bypass_sign_in(@admin)

      redirect_to admin_settings_security_path,
                  notice: "Password changed successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end

  def password_params
    params.require(:user).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end