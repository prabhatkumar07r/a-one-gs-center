module Api
  module V1
    class ApplicationController < Api::ApplicationController

      skip_before_action :authenticate_request, only: :health_check

      def health_check
        render json: {
          success: true,
          status: "ok",
          message: "A One GS Center API is running",
          timestamp: Time.current
        }, status: :ok
      end

    end
  end
end