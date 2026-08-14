# app/controllers/admin_controller.rb

class AdminController < ApplicationController
  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access Denied"
    end
  end
end