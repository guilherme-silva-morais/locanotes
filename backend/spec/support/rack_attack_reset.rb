# Rack::Attack uses a process-wide MemoryStore that survives between examples.
# Reset it before every request spec so throttle counters don't bleed across
# tests (and accidentally turn 401 into 429).
RSpec.configure do |config|
  config.before(:each, type: :request) do
    Rack::Attack.cache.store.clear
  end
end
