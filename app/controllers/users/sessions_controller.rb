class Users::SessionsController < Devise::SessionsController
  layout "auth"
  def new
    super
  end
   protected

  def after_sign_in_path_for(resource)

    case resource.role

    when "admin"
      dashboard_path

    when "teacher"
      teacher_dashboard_path

    when "student"
      homepage_path

    else
      root_path

    end

  end


  
end