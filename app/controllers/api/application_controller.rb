# File: app/controllers/api/application_controller.rb
# ये base controller होगा सभी API controllers के लिए

module Api
  class ApplicationController < ActionController::API
    # ActionController::API use कर रहे हैं (normal ActionController::Base नहीं)
    # क्योंकि API को HTML views नहीं चाहिए
    
    before_action :authenticate_request
    
    private
    
    def authenticate_request
      # Authentication logic (optional)
      # Token based authentication के लिए
      header = request.headers['Authorization']
      token = header.split(' ').last if header
      
      if token
        # Verify token logic
        # @current_user = User.find_by(token: token)
      else
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
    
    def current_user
      @current_user
    end
    
    def render_success(data = {}, message = "Success", status = :ok)
      render json: { success: true, message: message, data: data }, status: status
    end
    
    def render_error(message = "Error", status = :unprocessable_entity)
      render json: { success: false, error: message }, status: status
    end
  end
end