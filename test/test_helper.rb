ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "active_job/test_helper"
require "webmock/minitest" # also blocks any unstubbed real HTTP request

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper

    # Add more helper methods to be used by all tests here...

    # Sets ENV vars for the duration of the block (nil unsets one), then
    # restores them -- dotenv loads the developer's .env in tests too, so
    # tests that depend on provider config pin it explicitly.
    def with_env(vars)
      original = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end
  end
end
