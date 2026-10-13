
module Api
  module V1
    module Auth
      class PasswordsController < Api::ApplicationController
        skip_before_action :authenticate_request, only: [:create]

        def create
          email = params[:email].to_s.strip.downcase

          if email.blank?
            return render json: {
              success: false,
              error: "Email is required"
            }, status: :unprocessable_entity
          end

          user = User.find_by(email: email)
          user&.send_reset_password_instructions

          render json: {
            success: true,
            message: "If an account exists for that email, password reset instructions will be sent."
          }, status: :ok
        end
      end
    end
  end
end
