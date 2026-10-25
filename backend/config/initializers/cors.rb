require "uri"

origin = ENV.fetch("FRONTEND_ORIGIN") do
  raise "FRONTEND_ORIGIN must be set in production" if Rails.env.production?

  "http://localhost:3000"
end
begin
  uri = URI.parse(origin)
  valid = %w[http https].include?(uri.scheme) && uri.host.present? &&
    uri.userinfo.nil? && uri.path.empty? && uri.query.nil? && uri.fragment.nil? &&
    !origin.include?("*")
  raise URI::InvalidURIError unless valid
rescue URI::InvalidURIError
  raise ArgumentError, "FRONTEND_ORIGIN must be one HTTP(S) origin without a path or wildcard"
end

Rails.application.config.x.frontend_origin = origin
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins origin
    resource "*",
      headers: :any,
      methods: %i[get post patch delete options head],
      credentials: false
  end
end
