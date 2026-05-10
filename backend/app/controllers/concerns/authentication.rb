# Bearer-token authentication for the JSON API.
#
# Reads `Authorization: Bearer <jwt>`, decodes the JWT as an access token,
# and looks up the Session row whose id matches the token's `jti`. Logout
# is implemented by destroying the Session, which invalidates every JWT
# pointing at it (the lookup returns nil and we render 401).
#
# Controllers may opt out of authentication with `allow_unauthenticated_access`.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session.present?
    end

    def require_authentication
      resume_session || render_unauthorized
    end

    def resume_session
      Current.session ||= find_session_from_bearer_token
    end

    def find_session_from_bearer_token
      token = bearer_token
      return nil if token.blank?

      payload = JwtService.decode(token, expected_type: "access")
      Session.find_by(id: payload["jti"])
    rescue JwtService::Error
      nil
    end

    def bearer_token
      header = request.headers["Authorization"]
      return nil if header.blank?

      # RFC 7235: auth scheme is case-insensitive.
      match = header.match(/\ABearer +(.+)\z/i)
      match && match[1]
    end

    def render_unauthorized
      render json: { error: I18n.t("auth.unauthorized") }, status: :unauthorized
    end

    def start_new_session_for(user)
      user.sessions.create!(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      ).tap { |session| Current.session = session }
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
    end
end
