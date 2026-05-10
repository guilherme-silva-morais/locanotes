require "rails_helper"

# Exercises the Authentication concern via an anonymous controller that
# inherits all the auth behavior from ApplicationController.
RSpec.describe ApplicationController, type: :controller do
  controller do
    allow_unauthenticated_access only: :show

    def index
      render json: { user_id: Current.user.id, session_id: Current.session.id }
    end

    def show
      render json: { ok: true }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "show" => "anonymous#show"
    end
  end

  let(:user) { create(:user) }
  let(:user_session) { create(:session, user: user) }
  let(:access_token) { JwtService.encode_access(user_session) }

  describe "protected action without a token" do
    it "returns 401" do
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "responds with a localized error (pt-BR by default)" do
      get :index
      expect(JSON.parse(response.body)["error"]).to eq("Não autorizado")
    end

    it "responds in en when Accept-Language: en is sent" do
      request.headers["Accept-Language"] = "en"
      get :index
      expect(JSON.parse(response.body)["error"]).to eq("Unauthorized")
    end
  end

  describe "protected action with invalid credentials" do
    it "returns 401 when Authorization header lacks 'Bearer '" do
      request.headers["Authorization"] = "Token abc"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when token is malformed" do
      request.headers["Authorization"] = "Bearer not.a.real.token"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when access token is expired" do
      expired_token = nil
      travel_to(20.minutes.ago) { expired_token = JwtService.encode_access(user_session) }
      request.headers["Authorization"] = "Bearer #{expired_token}"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when token is signed with a different secret" do
      foreign = JWT.encode(
        { sub: user.id, jti: user_session.id.to_s, type: "access", exp: 1.hour.from_now.to_i },
        "a-different-secret",
        JwtService::ALGORITHM
      )
      request.headers["Authorization"] = "Bearer #{foreign}"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when a refresh token is used in place of access" do
      refresh = JwtService.encode_refresh(user_session)
      request.headers["Authorization"] = "Bearer #{refresh}"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the Session has been destroyed (logout/revocation)" do
      token = JwtService.encode_access(user_session)
      user_session.destroy
      request.headers["Authorization"] = "Bearer #{token}"
      get :index
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "protected action with valid access token" do
    it "returns 200 and exposes Current.user / Current.session" do
      request.headers["Authorization"] = "Bearer #{access_token}"
      get :index

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user_id"]).to eq(user.id)
      expect(body["session_id"]).to eq(user_session.id)
    end
  end

  describe "public action (allow_unauthenticated_access)" do
    it "returns 200 without any auth header" do
      get :show
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 even with a bogus Authorization header" do
      request.headers["Authorization"] = "Bearer bogus"
      get :show
      expect(response).to have_http_status(:ok)
    end
  end
end
