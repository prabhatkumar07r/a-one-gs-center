class Users::RegistrationsController < Devise::RegistrationsController
  layout "auth"

  def create
    build_resource(sign_up_params)

    if resource.save
      redirect_to new_user_session_path,
                  notice: "Account created successfully. Please check your email to confirm your account."
    else
      clean_up_passwords(resource)
      set_minimum_password_length

      render :new, status: :unprocessable_content
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(
      :name,
      :email,
      :mobile,
      :password,
      :password_confirmation
    )
  end
end