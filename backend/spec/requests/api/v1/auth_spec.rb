require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      {
        email_address: "new@example.com",
        password: "Password123",
        password_confirmation: "Password123"
      }
    end

    context "on success" do
      it "returns 201 with access_token, refresh_token, and user payload" do
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body).to have_key("access_token")
        expect(body).to have_key("refresh_token")
        expect(body["user"]).to include("id", "email_address")
        expect(body["user"]["email_address"]).to eq("new@example.com")
      end

      it "does not leak password_digest in the response" do
        post "/api/v1/auth/register", params: valid_params
        body = JSON.parse(response.body)
        expect(body["user"]).not_to have_key("password_digest")
      end

      it "creates the User and a Session" do
        expect { post "/api/v1/auth/register", params: valid_params }
          .to change(User, :count).by(1)
          .and change(Session, :count).by(1)
      end

      it "issues an access_token that authenticates the new session" do
        post "/api/v1/auth/register", params: valid_params
        token = JSON.parse(response.body)["access_token"]
        payload = JwtService.decode(token, expected_type: "access")
        expect(Session.find_by(id: payload["jti"])).to be_present
      end

      it "normalizes the email before storing" do
        post "/api/v1/auth/register", params: valid_params.merge(email_address: "  NEW@Example.COM  ")
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["user"]["email_address"]).to eq("new@example.com")
      end
    end

    context "on validation errors" do
      it "returns 422 when email is already taken" do
        create(:user, email_address: "new@example.com")
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body["errors"]["email_address"]).to be_present
      end

      it "returns 422 when password is weak (no digit)" do
        weak = valid_params.merge(password: "alphabetical", password_confirmation: "alphabetical")
        post "/api/v1/auth/register", params: weak

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["errors"]["password"]).to be_present
      end

      it "returns 422 when password is too short" do
        short = valid_params.merge(password: "Ab1", password_confirmation: "Ab1")
        post "/api/v1/auth/register", params: short

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["errors"]["password"]).to be_present
      end

      it "returns 422 when password_confirmation does not match" do
        mismatched = valid_params.merge(password_confirmation: "Different123")
        post "/api/v1/auth/register", params: mismatched

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 422 when email is missing" do
        post "/api/v1/auth/register", params: valid_params.except(:email_address)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 422 when email format is invalid" do
        post "/api/v1/auth/register", params: valid_params.merge(email_address: "not-an-email")
        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["errors"]["email_address"]).to be_present
      end

      it "returns localized password errors in pt-BR by default" do
        post "/api/v1/auth/register",
             params: valid_params.merge(password: "weak", password_confirmation: "weak")
        msgs = JSON.parse(response.body)["errors"]["password"].join
        expect(msgs.downcase).to match(/caractere|letra|n[uú]mero/)
      end

      it "returns localized password errors in en when Accept-Language: en" do
        post "/api/v1/auth/register",
             params: valid_params.merge(password: "weak", password_confirmation: "weak"),
             headers: { "Accept-Language" => "en" }
        msgs = JSON.parse(response.body)["errors"]["password"].join
        expect(msgs.downcase).to match(/character|letter|digit/)
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email_address: "login@example.com", password: "Password123") }

    context "on success" do
      it "returns 200 with access_token, refresh_token, and user payload" do
        post "/api/v1/auth/login",
             params: { email_address: "login@example.com", password: "Password123" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("access_token")
        expect(body).to have_key("refresh_token")
        expect(body["user"]["email_address"]).to eq("login@example.com")
      end

      it "creates a new Session" do
        expect {
          post "/api/v1/auth/login",
               params: { email_address: "login@example.com", password: "Password123" }
        }.to change(Session, :count).by(1)
      end

      it "authenticates case-insensitively (email normalization)" do
        post "/api/v1/auth/login",
             params: { email_address: "LOGIN@Example.COM", password: "Password123" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "on invalid credentials" do
      it "returns 401 with a generic message when password is wrong" do
        post "/api/v1/auth/login",
             params: { email_address: "login@example.com", password: "WrongPass1" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Email ou senha incorretos")
      end

      it "returns the same generic message when email is unknown (no user enumeration)" do
        post "/api/v1/auth/login",
             params: { email_address: "unknown@example.com", password: "Password123" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Email ou senha incorretos")
      end

      it "responds in en when Accept-Language: en is sent" do
        post "/api/v1/auth/login",
             params: { email_address: "login@example.com", password: "Wrong" },
             headers: { "Accept-Language" => "en" }
        expect(JSON.parse(response.body)["error"]).to eq("Invalid email or password")
      end

      it "does not create a Session on failed login" do
        expect {
          post "/api/v1/auth/login",
               params: { email_address: user.email_address, password: "wrong" }
        }.not_to change(Session, :count)
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let(:user) { create(:user) }
    let(:session) { create(:session, user: user) }
    let(:refresh_token) { JwtService.encode_refresh(session) }

    context "on success" do
      it "returns 200 with a new access_token" do
        post "/api/v1/auth/refresh", params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["access_token"]).to be_present

        new_payload = JwtService.decode(body["access_token"], expected_type: "access")
        expect(new_payload["sub"]).to eq(user.id)
        expect(new_payload["jti"]).to eq(session.id.to_s)
      end

      it "does not create a new Session (refresh reuses the existing one)" do
        session # touch to create
        expect {
          post "/api/v1/auth/refresh", params: { refresh_token: refresh_token }
        }.not_to change(Session, :count)
      end
    end

    context "on failure" do
      it "returns 401 when refresh_token is missing" do
        post "/api/v1/auth/refresh", params: {}
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when refresh_token is malformed" do
        post "/api/v1/auth/refresh", params: { refresh_token: "not.a.real.token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when refresh_token is expired (older than 7 days)" do
        expired = nil
        travel_to(8.days.ago) { expired = JwtService.encode_refresh(session) }
        post "/api/v1/auth/refresh", params: { refresh_token: expired }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when an access_token is sent in place of refresh" do
        access = JwtService.encode_access(session)
        post "/api/v1/auth/refresh", params: { refresh_token: access }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when the Session has been destroyed (revoked)" do
        session.destroy
        post "/api/v1/auth/refresh", params: { refresh_token: refresh_token }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    let(:user) { create(:user) }
    let(:session) { create(:session, user: user) }
    let(:access_token) { JwtService.encode_access(session) }

    it "returns 204 and destroys the Session" do
      session # ensure it exists before measuring change
      expect {
        delete "/api/v1/auth/logout",
               headers: { "Authorization" => "Bearer #{access_token}" }
      }.to change(Session, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Session.find_by(id: session.id)).to be_nil
    end

    it "returns 401 when no Authorization header is provided" do
      delete "/api/v1/auth/logout"
      expect(response).to have_http_status(:unauthorized)
    end

    it "invalidates the access_token (subsequent use returns 401)" do
      delete "/api/v1/auth/logout",
             headers: { "Authorization" => "Bearer #{access_token}" }
      expect(response).to have_http_status(:no_content)

      # Same token, replayed after logout — Session is gone, so auth rejects it.
      delete "/api/v1/auth/logout",
             headers: { "Authorization" => "Bearer #{access_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
