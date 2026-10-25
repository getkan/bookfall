class ApplicationController < ActionController::API
  rescue_from FeatureNotImplemented do |error|
    Rails.logger.warn("#{self.class.name}: #{error.message}")
    render json: { error: { code: "not_implemented", message: error.message } },
      status: :not_implemented
  end
end
