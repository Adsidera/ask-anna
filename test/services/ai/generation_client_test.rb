require "test_helper"

module AI
  class GenerationClientTest < ActiveSupport::TestCase
    test "wraps a connection-level Faraday failure as AI::GenerationClient::Error" do
      client = AI::GenerationClient.new(provider: "ollama")
      fake_connection = Object.new
      fake_connection.define_singleton_method(:post) do |*_args|
        raise Faraday::ConnectionFailed, "Connection refused - connect(2) for \"localhost\" port 11434"
      end

      client.stub(:ollama_connection, fake_connection) do
        error = assert_raises(AI::GenerationClient::Error) { client.generate("hello") }
        assert_match(/ollama generation request failed/i, error.message)
        assert_match(/connection refused/i, error.message)
      end
    end
  end
end
