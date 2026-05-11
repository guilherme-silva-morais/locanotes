# Override Rails 8 defaults with stricter values appropriate for an API-only app.
#
# Defaults Rails 8 already sends:
#   X-Content-Type-Options: nosniff
#   X-Permitted-Cross-Domain-Policies: none
#   Referrer-Policy: strict-origin-when-cross-origin
#   X-XSS-Protection: 0 (modern browsers ignore this header; explicit 0 is the
#                       recommended OWASP setting since the legacy filter was
#                       a source of XSS vulnerabilities itself)
#
# What we override / add:
#   X-Frame-Options: DENY — this is an API; embedding our responses in <iframe>
#                            is never legitimate, so we lock it tighter than
#                            the SAMEORIGIN default.
Rails.application.config.action_dispatch.default_headers.merge!(
  "X-Frame-Options" => "DENY"
)
