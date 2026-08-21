class Rack::Attack
  # Spec Fase 2, non-functional requirements: rate limit /ask per IP to
  # avoid abuse of the (comparatively expensive) generation model.
  throttle("ask/ip", limit: ENV.fetch("ASK_RATE_LIMIT_PER_MINUTE", 10).to_i, period: 1.minute) do |req|
    req.ip if req.path == "/ask" && req.post?
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "too many requests, please slow down" }.to_json ]
    ]
  end
end

Rails.application.config.middleware.use Rack::Attack

# Disabled by default in tests so the throttle doesn't make unrelated
# request specs flaky; individual tests can flip this back on.
Rack::Attack.enabled = !Rails.env.test?
