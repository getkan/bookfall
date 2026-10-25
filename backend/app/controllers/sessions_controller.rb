class SessionsController < ApplicationController
  class_attribute :login_rate_limit_store, default: SolidCache::Store.new

  before_action :limit_login_attempts

  def create
    username = params[:username]
    password = params[:password]
    user = User.authenticate_by(username: username, password: password) if username.is_a?(String) && password.is_a?(String) && password.present?

    if user&.is_admin?
      response.headers["Cache-Control"] = "no-store"
      render json: { token: user.generate_token_for(:api_access) }
    else
      render_error("unauthorized", "Invalid admin credentials", :unauthorized)
    end
  end

  private
    def limit_login_attempts
      peer = request.remote_addr
      trusted_peer = Rails.application.config.action_dispatch.trusted_proxies.any? { |proxy| proxy === peer }
      ip = trusted_peer ? request.remote_ip : peer
      raise "Login request has no peer IP" if ip.blank?

      count = login_rate_limit_store.increment("login-attempts:#{ip}", 1, expires_in: 3.minutes)
      raise "Login rate limit store did not record the attempt" unless count.is_a?(Integer)

      if count > 10
        Rails.logger.warn("Login rate limit exceeded")
        response.headers["Retry-After"] = "180"
        render_error("rate_limited", "Too many login attempts; retry later", :too_many_requests)
      end
    end
end
