# rspec-rails request specs default to www.example.com, which Rails 8's
# ActionDispatch::HostAuthorization blocks by default. Override the host to
# localhost (always in the allowlist) for the whole request spec suite.
RSpec.configure do |config|
  config.before(:each, type: :request) do
    host! "localhost"
  end
end
