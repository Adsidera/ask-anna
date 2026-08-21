module Admin
  # spec Fase 1: "CRUD per Document (admin-only)". HTTP Basic Auth is
  # enough for a single-admin personal site; no need for a sessions/users
  # system. Credentials MUST come from ENV -- see .env.example -- rather
  # than falling back to any default, so a misconfigured deploy fails
  # closed (503) instead of exposing the admin panel with a guessable
  # or empty password.
  class BaseController < ApplicationController
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      username = ENV["ADMIN_USERNAME"]
      password = ENV["ADMIN_PASSWORD"]

      if username.blank? || password.blank?
        render plain: "Admin panel is not configured (set ADMIN_USERNAME and ADMIN_PASSWORD).",
               status: :service_unavailable
        return
      end

      authenticate_or_request_with_http_basic("Ask Anna Admin") do |given_username, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_username.to_s, username) &
          ActiveSupport::SecurityUtils.secure_compare(given_password.to_s, password)
      end
    end
  end
end
