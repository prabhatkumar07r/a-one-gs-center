# ये base controller होगा सभी API controllers के लिए

module Api
  class ApplicationController < ActionController::API
    # API requests के लिए authentication required है
    # Health check को बाद में public रखा जा सकता है अगर जरूरत हो

    before_action :authenticate_request

    attr_reader :current_user

    private

    def authenticate_request
      token = bearer_token

      api_token = ApiTokenService.find_active(token)

      unless api_token
        render json: {
          success: false,
          error: "Unauthorized"
        }, status: :unauthorized

        return
      end

      @current_user = api_token.user
    end

    def bearer_token
      header = request.headers["Authorization"]

      return nil if header.blank?

      scheme, token = header.split(" ", 2)

      return nil unless scheme&.casecmp("Bearer")&.zero?

      token
    end

    def render_success(data = {}, message = "Success", status = :ok)
      render json: {
        success: true,
        message: message,
        data: data
      }, status: status
    end

    def render_error(message = "Error", status = :unprocessable_entity)
      render json: {
        success: false,
        error: message
      }, status: status
    end
  end
end