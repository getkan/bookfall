require "ipaddr"

Rails.application.config.action_dispatch.trusted_proxies =
  ENV.fetch("TRUSTED_PROXY_CIDRS", "").split(",").map { |cidr| IPAddr.new(cidr.strip) }
