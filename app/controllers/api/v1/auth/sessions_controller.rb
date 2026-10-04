module Api
  module V1
    module Auth
      class SessionsController < Api::ApplicationController

        # Login को authentication से exempt करना जरूरी है
        skip_before_action :authenticate_request, only: :create

        def create
          email = params[:email].to_s.strip.downcase
          password = params[:password].to_s

          if email.blank? || password.blank?
            return render json: {
              success: false,
              error: "Email and password are required"
            }, status: :unprocessable_entity
          end

          user = User.find_by(email: email)

          unless user && user.valid_password?(password)
            return render json: {
              success: false,
              error: "Invalid email or password"
            }, status: :unauthorized
          end

          token_data = ApiTokenService.issue!(user)

          render json: {
            success: true,
            message: "Login successful",
            data: {
              token: token_data[:token],
              expires_at: token_data[:expires_at],
              user: user_json(user)
            }
          }, status: :ok
        end

        def me
          render json: {
            success: true,
            data: {
              user: user_json(current_user)
            }
          }, status: :ok
        end

        def destroy
          token = bearer_token

          if token.blank?
            return render json: {
              success: false,
              error: "Unauthorized"
            }, status: :unauthorized
          end

          revoked = ApiTokenService.revoke!(token)

          unless revoked
            return render json: {
              success: false,
              error: "Unauthorized"
            }, status: :unauthorized
          end

          render json: {
            success: true,
            message: "Logout successful"
          }, status: :ok
        end

        private

        def user_json(user)
          {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
          }
        end

        def bearer_token
          header = request.headers["Authorization"]

          return nil if header.blank?

          scheme, token = header.split(" ", 2)

          return nil unless scheme&.casecmp("Bearer")&.zero?

          token
        end
      end
    end
  end
end