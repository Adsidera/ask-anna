# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.6
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq-dev libjemalloc2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# --- gems ---
FROM base AS gems

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# --- widget/homepage frontend (TypeScript + Tailwind, see package.json) ---
FROM node:22-slim AS frontend

WORKDIR /rails
COPY package.json package-lock.json tsconfig.json ./
RUN npm ci
COPY app/frontend app/frontend
# Tailwind v4 has no config file -- it auto-detects used classes by
# scanning templates near the CSS entry point, so app/views (the ERB
# templates) must be present at build time even though nothing here
# actually executes them.
COPY app/views app/views
RUN npm run build

# --- final image ---
FROM base

COPY --from=gems "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY . .
COPY --from=frontend /rails/public/application.css /rails/public/application.css
COPY --from=frontend /rails/public/widget.css /rails/public/widget.css
COPY --from=frontend /rails/public/home.js /rails/public/home.js
COPY --from=frontend /rails/public/widget.js /rails/public/widget.js

RUN bundle exec bootsnap precompile app/ lib/

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]
