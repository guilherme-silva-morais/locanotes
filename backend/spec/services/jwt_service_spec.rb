require "rails_helper"

RSpec.describe JwtService do
  let(:session) { create(:session) }

  describe ".encode_access then .decode" do
    it "round-trips and exposes sub, jti, type, exp" do
      token = described_class.encode_access(session)
      payload = described_class.decode(token, expected_type: "access")

      expect(payload["sub"]).to eq(session.user_id)
      expect(payload["jti"]).to eq(session.id.to_s)
      expect(payload["type"]).to eq("access")
      expect(payload["exp"]).to be_within(2).of(15.minutes.from_now.to_i)
      expect(payload["iat"]).to be_within(2).of(Time.current.to_i)
    end

    it "raises ExpiredToken when the access token is older than 15 minutes" do
      token = nil
      travel_to(20.minutes.ago) { token = described_class.encode_access(session) }

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(JwtService::ExpiredToken)
    end

    it "raises InvalidToken when decoded as 'refresh'" do
      token = described_class.encode_access(session)

      expect { described_class.decode(token, expected_type: "refresh") }
        .to raise_error(JwtService::InvalidToken, /wrong token type/)
    end
  end

  describe ".encode_refresh then .decode" do
    it "round-trips with type=refresh and exp around 7 days from now" do
      token = described_class.encode_refresh(session)
      payload = described_class.decode(token, expected_type: "refresh")

      expect(payload["type"]).to eq("refresh")
      expect(payload["exp"]).to be_within(5).of(7.days.from_now.to_i)
    end

    it "raises ExpiredToken when the refresh token is older than 7 days" do
      token = nil
      travel_to(8.days.ago) { token = described_class.encode_refresh(session) }

      expect { described_class.decode(token, expected_type: "refresh") }
        .to raise_error(JwtService::ExpiredToken)
    end

    it "raises InvalidToken when decoded as 'access'" do
      token = described_class.encode_refresh(session)

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken, /wrong token type/)
    end
  end

  describe ".decode rejecting malicious or malformed input" do
    it "raises InvalidToken when the signature is tampered" do
      token = described_class.encode_access(session)
      parts = token.split(".")
      parts[2] = "tampered_signature"
      tampered = parts.join(".")

      expect { described_class.decode(tampered, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken when the token is malformed" do
      expect { described_class.decode("not.a.real.token", expected_type: "access") }
        .to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken when the token was signed with a different secret" do
      foreign_token = JWT.encode(
        { sub: session.user_id, jti: session.id.to_s, type: "access", exp: 1.hour.from_now.to_i },
        "a-different-secret",
        described_class::ALGORITHM
      )

      expect { described_class.decode(foreign_token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken when jti is missing from the payload" do
      orphan_token = JWT.encode(
        { sub: session.user_id, type: "access", exp: 1.hour.from_now.to_i },
        ENV.fetch("JWT_SECRET"),
        described_class::ALGORITHM
      )

      expect { described_class.decode(orphan_token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken, /missing jti/)
    end

    it "raises InvalidToken when sub is missing from the payload" do
      orphan_token = JWT.encode(
        { jti: "x", type: "access", exp: 1.hour.from_now.to_i },
        ENV.fetch("JWT_SECRET"),
        described_class::ALGORITHM
      )

      expect { described_class.decode(orphan_token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken, /missing sub/)
    end

    it "raises InvalidToken when exp is missing (tokens cannot be eternal)" do
      eternal_token = JWT.encode(
        { sub: session.user_id, jti: session.id.to_s, type: "access" },
        ENV.fetch("JWT_SECRET"),
        described_class::ALGORITHM
      )

      expect { described_class.decode(eternal_token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken, /missing exp/)
    end

    it "rejects tokens that use the 'none' algorithm (alg=none attack)" do
      malicious = JWT.encode(
        { sub: session.user_id, jti: session.id.to_s, type: "access", exp: 1.hour.from_now.to_i },
        nil,
        "none"
      )

      expect { described_class.decode(malicious, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken)
    end

    it "rejects tokens signed with a different algorithm (HS512 instead of HS256)" do
      hs512_token = JWT.encode(
        { sub: session.user_id, jti: session.id.to_s, type: "access", exp: 1.hour.from_now.to_i },
        ENV.fetch("JWT_SECRET"),
        "HS512"
      )

      expect { described_class.decode(hs512_token, expected_type: "access") }
        .to raise_error(JwtService::InvalidToken)
    end
  end

  describe "concurrent sessions are independently revocable" do
    it "destroying one session does not invalidate tokens from another session of the same user" do
      user = create(:user)
      device_a = create(:session, user: user, user_agent: "Device A")
      device_b = create(:session, user: user, user_agent: "Device B")

      token_a = described_class.encode_access(device_a)
      token_b = described_class.encode_access(device_b)

      device_a.destroy

      # Token A still passes JWT validation, but the Session lookup returns nil
      # (caller treats nil as revoked — the Authentication concern returns 401).
      payload_a = described_class.decode(token_a, expected_type: "access")
      expect(Session.find_by(id: payload_a["jti"])).to be_nil

      # Token B still resolves to the live Session, unaffected.
      payload_b = described_class.decode(token_b, expected_type: "access")
      expect(Session.find_by(id: payload_b["jti"])).to eq(device_b)
    end
  end
end
