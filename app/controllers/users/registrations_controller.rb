class Users::RegistrationsController < Devise::RegistrationsController
  layout "auth"

  def create
    build_resource(sign_up_params)

    if resource.save

      begin
        BrevoService.send_confirmation(resource)

        redirect_to new_user_session_path,
                    notice: "Account created successfully. Please check your email to confirm your account."

      rescue StandardError => e

        Rails.logger.error(
          "Confirmation email failed: #{e.class}: #{e.message}"
        )

        redirect_to new_user_session_path,
                    alert: "Account created, but confirmation email could not be sent."
      end

    else

      clean_up_passwords resource
      set_minimum_password_length

      render :new,
             status: :unprocessable_entity
    end
  end
end