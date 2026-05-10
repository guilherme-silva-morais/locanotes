# Rate-limit and throttle rules at the Rack layer. Brief mandates in-memory
# storage (no Redis), so we attach a dedicated MemoryStore rather than reusing
# Rails.cache — Rails.cache is :null_store in test, which would defeat the
# throttle entirely.
class Rack::Attack
  cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttles ###

  # 5 login attempts per minute per IP. The 6th in the same minute gets 429.
  throttle("logins/ip", limit: 5, period: 1.minute) do |req|
    if req.post? && req.path == "/api/v1/auth/login"
      req.ip
    end
  end

  # 60 authenticated requests per minute per Bearer token. The 61st gets 429.
  throttle("authenticated/token", limit: 60, period: 1.minute) do |req|
    auth = req.env["HTTP_AUTHORIZATION"].to_s
    auth.split(" ", 2).last if auth.start_with?("Bearer ")
  end

  ### Custom throttled response (localized) ###

  self.throttled_responder = lambda do |request|
    locale = locale_from_request(request) || I18n.default_locale
    body = { error: I18n.t("auth.rate_limited", locale: locale) }.to_json
    [ 429, { "content-type" => "application/json; charset=utf-8" }, [ body ] ]
  end

  # Parse Accept-Language manually because we're below the controller stack.
  def self.locale_from_request(request)
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    return nil if header.empty?

    header.split(",").each do |part|
      tag = part.split(";").first.to_s.strip.to_sym
      return tag if I18n.available_locales.include?(tag)
    end
    nil
  end
end
