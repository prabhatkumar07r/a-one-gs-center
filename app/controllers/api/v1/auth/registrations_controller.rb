module Api
  module V1
    module Auth
      class RegistrationsController < Api::ApplicationController
        skip_before_action :authenticate_request, only: :create

        def create
          name = params[:name].to_s.strip
          email = params[:email].to_s.strip.downcase
          password = params[:password].to_s
          password_confirmation = params[:password_confirmation].to_s

          if name.blank? || email.blank? || password.blank?
            return render json: {
              success: false,
              error: "Name, email and password are required"
            }, status: :unprocessable_entity
          end

          unless password == password_confirmation
            return render json: {
              success: false,
              error: "Password confirmation does not match"
            }, status: :unprocessable_entity
          end

          user = User.new(
            name: name,
            email: email,
            password: password,
            password_confirmation: password_confirmation,
            role: :student
          )

          if user.save
            render json: {
              success: true,
              message: "Account created successfully. Please log in.",
              data: {
                user: {
                  id: user.id,
                  name: user.name,
                  email: user.email,
                  role: user.role,
                  image_url: nil
                }
              }
            }, status: :created
          else
            render json: {
              success: false,
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
