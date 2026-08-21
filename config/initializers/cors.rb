# Allows the widget (Fase 3) to call POST /ask from whatever origin it's
# embedded on (personal site, Substack, ...), which is a different origin
# than this API in production. /ask is public, unauthenticated, and
# doesn't use cookies, so a permissive origin list is safe here; scope it
# down via ALLOWED_ORIGINS if this API ever gains anything origin-sensitive.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "*").split(",").map(&:strip)

    resource "/ask",
      headers: :any,
      methods: [ :post, :options ],
      credentials: false
  end
end
