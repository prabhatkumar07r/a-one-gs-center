class Admin::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  # ================= SETTINGS HOME =================

  def index
  end

  # ================= NOTIFICATIONS =================

  def notifications
    @admin = current_user
  end

  def update_notifications
    @admin = current_user

    if @admin.update(notification_params)
      redirect_to admin_settings_notifications_path,
                  notice: "Notification settings updated successfully."
    else
      render :notifications, status: :unprocessable_entity
    end
  end

  # ================= WEBSITE SETTINGS =================

  def website
    @admin = current_user
  end

  def update_website
    @admin = current_user

    if @admin.update(website_params)
      redirect_to admin_settings_website_path,
                  notice: "Website settings updated successfully."
    else
      render :website, status: :unprocessable_entity
    end
  end

  # ================= SECURITY =================

  def security
    @admin = current_user
  end

  # ================= CHANGE PASSWORD =================

  def password
    @admin = current_user
  end

  def update_password
    @admin = current_user

    if @admin.update_with_password(password_params)
      bypass_sign_in(@admin)

      redirect_to admin_settings_security_path,
                  notice: "Password updated successfully."
    else
      render :password, status: :unprocessable_entity
    end
  end

  private

  # ================= ADMIN ACCESS =================

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end

  # ================= NOTIFICATION PARAMS =================

  def notification_params
    params.require(:user).permit(
      :email_notifications,
      :system_notifications,
      :student_notifications,
      :teacher_notifications
    )
  end

  # ================= WEBSITE PARAMS =================

  def website_params
    params.require(:user).permit(
      :website_name,
      :website_email,
      :website_mobile,
      :website_description,
      :website_address
    )
  end

  # ================= PASSWORD PARAMS =================

  def password_params
    params.require(:user).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end