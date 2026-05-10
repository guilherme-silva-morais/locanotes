# Encodes and decodes JSON Web Tokens used for Bearer authentication.
#
# Each token carries:
#   - sub  : the User id
#   - jti  : the Session id (logout destroys the Session, invalidating the token)
#   - type : "access" or "refresh" (mismatched types are rejected at decode)
#   - iat  : issued-at (epoch seconds)
#   - exp  : expiry (epoch seconds)
#
# Access tokens live 15 minutes; refresh tokens live 7 days.
class JwtService
  ACCESS_TTL = 15.minutes
  REFRESH_TTL = 7.days
  ALGORITHM = "HS256"

  Error         = Class.new(StandardError)
  ExpiredToken  = Class.new(Error)
  InvalidToken  = Class.new(Error)

  class << self
    def encode_access(session)
      encode(session, type: "access", ttl: ACCESS_TTL)
    end

    def encode_refresh(session)
      encode(session, type: "refresh", ttl: REFRESH_TTL)
    end

    def decode(token, expected_type:)
      payload, _header = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      raise InvalidToken, "wrong token type" unless payload["type"] == expected_type
      raise InvalidToken, "missing jti or sub" if payload["jti"].blank? || payload["sub"].blank?

      payload
    rescue JWT::ExpiredSignature
      raise ExpiredToken
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    private

    def encode(session, type:, ttl:)
      now = Time.current
      payload = {
        sub: session.user_id,
        jti: session.id.to_s,
        type: type,
        iat: now.to_i,
        exp: (now + ttl).to_i
      }
      JWT.encode(payload, secret, ALGORITHM)
    end

    def secret
      key = ENV["JWT_SECRET"]
      raise InvalidToken, "JWT_SECRET is not configured" if key.blank?

      key
    end
  end
end
