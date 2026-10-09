
module Api
  module V1
    class ProfileController < Api::ApplicationController
      def show
        render json: {
          success: true,
          data: { user: profile_json(current_user) }
        }, status: :ok
      end

      def update
        user = current_user

        if params[:image].present?
          uploaded_image = params[:image]

          unless uploaded_image.respond_to?(:content_type) &&
                 uploaded_image.content_type.to_s.start_with?("image/")
            return render json: {
              success: false,
              error: "Please upload a valid image."
            }, status: :unprocessable_entity
          end

          if uploaded_image.respond_to?(:size) &&
             uploaded_image.size > 5.megabytes
            return render json: {
              success: false,
              error: "Image size must be 5 MB or less."
            }, status: :unprocessable_entity
          end
        end

        if user.update(profile_params)
          user.image.attach(params[:image]) if params[:image].present?

          render json: {
            success: true,
            message: "Profile updated successfully.",
            data: { user: profile_json(user) }
          }, status: :ok
        else
          render json: {
            success: false,
            errors: user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.permit(:name)
      end

      def profile_json(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          image_url: user.image.attached? ?
            Rails.application.routes.url_helpers.rails_blob_path(
              user.image,
              only_path: true
            ) : nil
        }
      end
    end
  end
end