class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Authentication

  # `set_locale` must run before `require_authentication` so unauthenticated
  # responses are localized according to the request's Accept-Language.
  prepend_before_action :set_locale

  # Cross-user access returns 404 (not 403) so we don't leak the existence
  # of records that belong to other users.
  rescue_from Pundit::NotAuthorizedError, with: :handle_pundit_not_authorized

  private

  # Tells Pundit which "user" to feed into policies. We don't use `current_user`
  # (that's a Devise convention); instead we expose the user through Current.
  def pundit_user
    Current.user
  end

  def handle_pundit_not_authorized
    head :not_found
  end

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
