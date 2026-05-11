require "rails_helper"

# These specs lock in the default security headers Rails 8 ships, plus the
# stricter X-Frame-Options we override in config/initializers/security_headers.rb.
RSpec.describe "Security response headers", type: :request do
  let(:user) { create(:user) }
  let(:session) { create(:session, user: user) }

  it "responds with strict security headers on a public endpoint" do
    get "/up"
    expect_security_headers(response)
  end

  it "responds with strict security headers on an authenticated endpoint" do
    get "/api/v1/notes", headers: { "Authorization" => "Bearer #{JwtService.encode_access(session)}" }
    expect_security_headers(response)
  end

  it "responds with strict security headers on an unauthenticated 401" do
    get "/api/v1/notes"
    expect(response).to have_http_status(:unauthorized)
    expect_security_headers(response)
  end

  it "responds with strict security headers on a 422 validation error" do
    post "/api/v1/auth/register", params: { email_address: "", password: "" }
    expect(response).to have_http_status(:unprocessable_content)
    expect_security_headers(response)
  end

  def expect_security_headers(response)
    # API responses must never be embeddable. DENY is stricter than the
    # Rails default SAMEORIGIN.
    expect(response.headers["X-Frame-Options"]).to eq("DENY")

    # Browsers must respect the Content-Type we set, not guess from the body.
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")

    # No legacy Flash / Silverlight cross-domain policy files allowed.
    expect(response.headers["X-Permitted-Cross-Domain-Policies"]).to eq("none")

    # Don't leak full URLs to other origins on navigation.
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")

    # The legacy browser filter is intentionally OFF (per OWASP guidance —
    # the filter itself introduced bugs in older browsers).
    expect(response.headers["X-XSS-Protection"]).to eq("0")
  end
end
