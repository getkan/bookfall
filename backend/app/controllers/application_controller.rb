class ApplicationController < ActionController::API
  rescue_from FeatureNotImplemented do |error|
    Rails.logger.warn("#{self.class.name}: #{error.message}")
    render json: { error: { code: "not_implemented", message: error.message } },
      status: :not_implemented
  end

  private
    def require_admin
      authorization = request.headers["Authorization"].to_s
      match = authorization.match(/\ABearer ([^\s]+)\z/i)
      user = User.find_by_token_for(:api_access, match[1]) if match

      if user.nil?
        render_error("unauthorized", "Valid bearer authentication is required", :unauthorized)
      elsif !user.is_admin?
        render_error("forbidden", "Admin access is required", :forbidden)
      end
    end

    def render_error(code, message, status)
      render json: { error: { code: code, message: message } }, status: status
    end
end
