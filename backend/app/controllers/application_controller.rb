class ApplicationController < ActionController::API
  include Authentication

  # `set_locale` must run before `require_authentication` so unauthenticated
  # responses are localized according to the request's Accept-Language.
  prepend_before_action :set_locale

  private

  def set_locale
    I18n.locale = locale_from_accept_language_header || I18n.default_locale
  end

  def locale_from_accept_language_header
    header = request.headers["Accept-Language"]
    return nil if header.blank?

    header.split(",").each do |part|
      tag = part.split(";").first.to_s.strip.to_sym
      return tag if I18n.available_locales.include?(tag)
    end
    nil
  end
end
