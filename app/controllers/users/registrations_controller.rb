class Users::RegistrationsController < Devise::RegistrationsController
  layout "auth"
   protected

  def after_sign_up_path_for(resource)
    new_user_session_path
  end


end