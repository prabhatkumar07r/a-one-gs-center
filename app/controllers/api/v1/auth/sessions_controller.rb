require "googleauth"
module Api
  module V1
    module Auth
      class SessionsController < Api::ApplicationController

        # Login को authentication से exempt करना जरूरी है
        skip_before_action :authenticate_request, only: [:create, :google]

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


        
def google
  id_token = params[:id_token].to_s
  client_id = ENV["GOOGLE_CLIENT_ID"].to_s

  if id_token.blank?
    return render json: {
      success: false,
      error: "Google ID token is required"
    }, status: :unprocessable_entity
  end

  if client_id.blank?
    return render json: {
      success: false,
      error: "Google login is not configured on the server"
    }, status: :internal_server_error
  end

  payload = Google::Auth::IDTokens.verify_oidc(
    id_token,
    aud: client_id
  )

  email = payload["email"].to_s.strip.downcase
  email_verified = payload["email_verified"] == true ||
                   payload["email_verified"].to_s == "true"

  unless email.present? && email_verified
    return render json: {
      success: false,
      error: "A verified Google email is required"
    }, status: :unauthorized
  end

  user = User.find_by(email: email)

  unless user
    user = User.new(
      email: email,
      name: payload["name"].presence || email.split("@").first,
      password: Devise.friendly_token(40),
      role: :student
    )
    user.save!
  end

  token_data = ApiTokenService.issue!(user)

  render json: {
    success: true,
    message: "Google login successful",
    data: {
      token: token_data[:token],
      expires_at: token_data[:expires_at],
      user: user_json(user)
    }
  }, status: :ok

rescue Google::Auth::IDTokens::VerificationError,
       Google::Auth::IDTokens::KeySourceError
  render json: {
    success: false,
    error: "Google token verification failed"
  }, status: :unauthorized

rescue ActiveRecord::RecordInvalid => e
  render json: {
    success: false,
    error: e.record.errors.full_messages.join(", ")
  }, status: :unprocessable_entity
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
            role: user.role,
            image_url: if user.image.attached?
              Rails.application.routes.url_helpers.rails_blob_url(
                user.image,
                host: "aonegscenter.com",
                protocol: "https"
              )
            end
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