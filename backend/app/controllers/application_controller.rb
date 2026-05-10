class ApplicationController < ActionController::API
  # TODO(phase-2.4): re-include Authentication after rewriting concern for JWT/API-only.
  # The generator-provided concern uses helper_method / cookies / redirect_to,
  # which aren't available in ActionController::API.
  # include Authentication

  before_action :set_locale

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
