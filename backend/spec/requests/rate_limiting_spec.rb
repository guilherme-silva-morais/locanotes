require "rails_helper"

RSpec.describe "Rate limiting (Rack::Attack)", type: :request do
  before { Rack::Attack.cache.store.clear }

  describe "login throttle — 5 attempts per minute per IP" do
    let!(:user) { create(:user, email_address: "rate@example.com", password: "Password123") }

    def attempt_login(password: "wrong-password")
      post "/api/v1/auth/login",
           params: { email_address: "rate@example.com", password: password }
    end

    it "allows up to 5 attempts in the window" do
      5.times do
        attempt_login
        expect(response.status).not_to eq(429)
      end
    end

    it "returns 429 on the 6th attempt" do
      5.times { attempt_login }
      attempt_login
      expect(response).to have_http_status(:too_many_requests)
    end

    it "does not count requests to other endpoints toward the login throttle" do
      5.times { attempt_login }
      # Hitting an unrelated endpoint must NOT reset or share the counter
      get "/up"
      expect(response.status).not_to eq(429)
      # And the 6th login is still throttled
      attempt_login
      expect(response).to have_http_status(:too_many_requests)
    end

    it "responds with a localized message (pt-BR by default)" do
      5.times { attempt_login }
      attempt_login
      expect(JSON.parse(response.body)["error"]).to match(/muitas tentativas|tente novamente/i)
    end

    it "responds in en when Accept-Language: en is sent" do
      5.times { attempt_login }
      post "/api/v1/auth/login",
           params: { email_address: "rate@example.com", password: "wrong-password" },
           headers: { "Accept-Language" => "en" }
      expect(JSON.parse(response.body)["error"]).to match(/too many|try again/i)
    end
  end

  describe "authenticated requests throttle — 60 per minute per Bearer token" do
    let(:user) { create(:user) }
    let(:user_session) { create(:session, user: user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtService.encode_access(user_session)}" } }

    it "allows up to 60 requests with the same token" do
      60.times do
        get "/api/v1/notes", headers: headers
        expect(response.status).not_to eq(429)
      end
    end

    it "returns 429 on the 61st request with the same token" do
      60.times { get "/api/v1/notes", headers: headers }
      get "/api/v1/notes", headers: headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "tracks counters independently per token" do
      other_session = create(:session, user: user)
      other_headers = { "Authorization" => "Bearer #{JwtService.encode_access(other_session)}" }

      60.times { get "/api/v1/notes", headers: headers }
      # First token is at the cap; the OTHER token still has full quota
      get "/api/v1/notes", headers: other_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
