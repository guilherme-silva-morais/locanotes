# API-only Rails + a separate Vue SPA means every browser request is
# cross-origin. We allow the frontend origin (configurable via env var) and
# expose all verbs we actually use.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")

    resource "*",
      headers: :any,
      methods: %i[get post patch put delete options head],
      expose: %w[Content-Type]
  end
end
