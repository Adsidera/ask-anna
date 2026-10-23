source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Vector similarity search on top of pgvector
gem "neighbor"

# Background jobs
gem "sidekiq"

# HTTP client for calling embedding/generation APIs (Ollama, Groq, ...)
gem "faraday"
gem "faraday-retry"

# Rate limiting / request throttling
gem "rack-attack"

# Deterministic profanity/insult check on incoming questions -- a 0.6B
# generation model can't be trusted to reliably self-moderate through a
# prompt instruction (see Rag::QueryService), so this is handled in code
# before the question ever reaches it.
gem "obscenity"

# CORS so the widget (Fase 3) can call /ask from a different origin
# (personal site / Substack) than where this API is deployed
gem "rack-cors"

# Strip HTML when ingesting documents from a URL
gem "nokogiri"

# Extract text from uploaded PDFs when ingesting documents
gem "pdf-reader"

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # Loads environment variables from .env for local development
  gem "dotenv-rails"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Pin to minitest 5.x: 6.x split out minitest/mock (used by Object#stub),
  # which several of this app's tests rely on to fake AI::EmbeddingClient
  # and AI::GenerationClient without hitting Ollama/Groq.
  gem "minitest", "~> 5.25"

  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Stubs HTTP at the Net::HTTP level, so the AI clients and HtmlFetcher are tested through their real Faraday stack
  gem "webmock"

  # Mutation testing: mutates app code and checks the suite catches it [https://github.com/davidteren/mutineer]
  gem "mutineer", require: false
end
