require "test_helper"

module AI
  class EmbeddingClientTest < ActiveSupport::TestCase
    OLLAMA_URL = "http://ollama.test:11434"

    test "wraps a connection-level Faraday failure as AI::EmbeddingClient::Error" do
      client = AI::EmbeddingClient.new(provider: "ollama")
      fake_connection = Object.new
      fake_connection.define_singleton_method(:post) do |*_args|
        raise Faraday::ConnectionFailed, "Connection refused - connect(2) for \"localhost\" port 11434"
      end

      client.stub(:ollama_connection, fake_connection) do
        error = assert_raises(AI::EmbeddingClient::Error) { client.embed("hello") }
        assert_match(/ollama embedding request failed/i, error.message)
        assert_match(/connection refused/i, error.message)
      end
    end

    test "embeds via Ollama's /api/embeddings" do
      stub_request(:post, "#{OLLAMA_URL}/api/embeddings")
        .with(body: { model: "nomic-embed-text", prompt: "hello" }.to_json, headers: { "Content-Type" => "application/json" })
        .to_return_json(body: { embedding: [ 0.1, 0.2 ] })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        assert_equal [ 0.1, 0.2 ], AI::EmbeddingClient.new(provider: "ollama", model: "nomic-embed-text").embed("hello")
      end
    end

    test "raises when Ollama responds with an error status" do
      stub_request(:post, "#{OLLAMA_URL}/api/embeddings").to_return_json(status: 404, body: { error: "model not found" })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        error = assert_raises(AI::EmbeddingClient::Error) { AI::EmbeddingClient.new(provider: "ollama").embed("hello") }
        assert_match "(404)", error.message
        assert_match "model not found", error.message
      end
    end

    test "raises when Ollama's response has no embedding" do
      stub_request(:post, "#{OLLAMA_URL}/api/embeddings").to_return_json(body: { embedding: [] })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        error = assert_raises(AI::EmbeddingClient::Error) { AI::EmbeddingClient.new(provider: "ollama").embed("hello") }
        assert_match "missing 'embedding'", error.message
      end
    end

    test "embeds via OpenAI's /embeddings with the OpenAI key" do
      stub_request(:post, "https://openai.test/v1/embeddings")
        .with(body: { model: "text-embedding-3-small", input: "hello" }.to_json, headers: { "Authorization" => "Bearer openai-key" })
        .to_return_json(body: { data: [ { embedding: [ 0.3, 0.4 ] } ] })

      with_env("OPENAI_API_URL" => "https://openai.test/v1", "OPENAI_API_KEY" => "openai-key", "EMBEDDING_API_KEY" => nil) do
        assert_equal [ 0.3, 0.4 ], AI::EmbeddingClient.new(provider: "openai", model: "text-embedding-3-small").embed("hello")
      end
    end

    test "embeds via Groq's URL with the Groq key" do
      stub_request(:post, "https://groq.test/v1/embeddings")
        .with(headers: { "Authorization" => "Bearer groq-key" })
        .to_return_json(body: { data: [ { embedding: [ 0.5 ] } ] })

      with_env("GROQ_API_URL" => "https://groq.test/v1", "GROQ_API_KEY" => "groq-key", "EMBEDDING_API_KEY" => nil) do
        assert_equal [ 0.5 ], AI::EmbeddingClient.new(provider: "groq").embed("hello")
      end
    end

    test "EMBEDDING_API_KEY takes precedence over the provider-specific key" do
      stub_request(:post, "https://openai.test/v1/embeddings")
        .with(headers: { "Authorization" => "Bearer embedding-key" })
        .to_return_json(body: { data: [ { embedding: [ 0.6 ] } ] })

      with_env("OPENAI_API_URL" => "https://openai.test/v1", "OPENAI_API_KEY" => "openai-key", "EMBEDDING_API_KEY" => "embedding-key") do
        assert_equal [ 0.6 ], AI::EmbeddingClient.new(provider: "openai").embed("hello")
      end
    end

    test "raises when an OpenAI-compatible provider responds with an error status" do
      stub_request(:post, "https://openai.test/v1/embeddings").to_return_json(status: 401, body: { error: "bad key" })

      with_env("OPENAI_API_URL" => "https://openai.test/v1") do
        error = assert_raises(AI::EmbeddingClient::Error) { AI::EmbeddingClient.new(provider: "openai").embed("hello") }
        assert_match "openai embedding request failed (401)", error.message
      end
    end

    test "raises when an OpenAI-compatible response has no embedding" do
      stub_request(:post, "https://openai.test/v1/embeddings").to_return_json(body: { data: [] })

      with_env("OPENAI_API_URL" => "https://openai.test/v1") do
        error = assert_raises(AI::EmbeddingClient::Error) { AI::EmbeddingClient.new(provider: "openai").embed("hello") }
        assert_match "missing data[0].embedding", error.message
      end
    end

    test "raises on an unknown provider" do
      error = assert_raises(AI::EmbeddingClient::Error) { AI::EmbeddingClient.new(provider: "nope").embed("hello") }
      assert_match "Unknown embedding provider", error.message
    end
  end
end
