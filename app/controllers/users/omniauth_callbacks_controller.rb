class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def google_oauth2

    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user,
        event: :authentication

      flash[:notice] = "Successfully signed in with Google"

    else
      redirect_to new_user_session_path,
        alert: "Google login failed"
    end

  end

end