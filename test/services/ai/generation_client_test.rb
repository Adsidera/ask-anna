require "test_helper"

module AI
  class GenerationClientTest < ActiveSupport::TestCase
    OLLAMA_URL = "http://ollama.test:11434"
    GROQ_URL = "https://groq.test/v1"

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

    test "generates via Ollama's /api/generate without streaming" do
      stub_request(:post, "#{OLLAMA_URL}/api/generate")
        .with(body: { model: "qwen3:0.6b", prompt: "hello", stream: false }.to_json, headers: { "Content-Type" => "application/json" })
        .to_return_json(body: { response: "Hi there." })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        assert_equal "Hi there.", AI::GenerationClient.new(provider: "ollama", model: "qwen3:0.6b").generate("hello")
      end
    end

    test "raises when Ollama responds with an error status" do
      stub_request(:post, "#{OLLAMA_URL}/api/generate").to_return_json(status: 500, body: { error: "out of memory" })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        error = assert_raises(AI::GenerationClient::Error) { AI::GenerationClient.new(provider: "ollama").generate("hello") }
        assert_match "(500)", error.message
        assert_match "out of memory", error.message
      end
    end

    test "raises when Ollama's response has no 'response' field" do
      stub_request(:post, "#{OLLAMA_URL}/api/generate").to_return_json(body: { done: true })

      with_env("OLLAMA_URL" => OLLAMA_URL) do
        error = assert_raises(AI::GenerationClient::Error) { AI::GenerationClient.new(provider: "ollama").generate("hello") }
        assert_match "missing 'response'", error.message
      end
    end

    test "generates via Groq's /chat/completions with the generation key" do
      stub_request(:post, "#{GROQ_URL}/chat/completions")
        .with(
          body: { model: "llama-3.1-8b-instant", messages: [ { role: "user", content: "hello" } ] }.to_json,
          headers: { "Authorization" => "Bearer generation-key" }
        )
        .to_return_json(body: { choices: [ { message: { content: "Hi from Groq." } } ] })

      with_env("GROQ_API_URL" => GROQ_URL, "GENERATION_API_KEY" => "generation-key", "GROQ_API_KEY" => "groq-key") do
        assert_equal "Hi from Groq.", AI::GenerationClient.new(provider: "groq", model: "llama-3.1-8b-instant").generate("hello")
      end
    end

    test "falls back to GROQ_API_KEY when GENERATION_API_KEY is blank" do
      stub_request(:post, "#{GROQ_URL}/chat/completions")
        .with(headers: { "Authorization" => "Bearer groq-key" })
        .to_return_json(body: { choices: [ { message: { content: "ok" } } ] })

      with_env("GROQ_API_URL" => GROQ_URL, "GENERATION_API_KEY" => "", "GROQ_API_KEY" => "groq-key") do
        assert_equal "ok", AI::GenerationClient.new(provider: "groq").generate("hello")
      end
    end

    test "raises when Groq responds with an error status" do
      stub_request(:post, "#{GROQ_URL}/chat/completions").to_return_json(status: 401, body: { error: "bad key" })

      with_env("GROQ_API_URL" => GROQ_URL) do
        error = assert_raises(AI::GenerationClient::Error) { AI::GenerationClient.new(provider: "groq").generate("hello") }
        assert_match "Groq generation request failed (401)", error.message
      end
    end

    test "raises when Groq's response has no message content" do
      stub_request(:post, "#{GROQ_URL}/chat/completions").to_return_json(body: { choices: [] })

      with_env("GROQ_API_URL" => GROQ_URL) do
        error = assert_raises(AI::GenerationClient::Error) { AI::GenerationClient.new(provider: "groq").generate("hello") }
        assert_match "missing choices[0].message.content", error.message
      end
    end

    test "raises on an unknown provider" do
      error = assert_raises(AI::GenerationClient::Error) { AI::GenerationClient.new(provider: "nope").generate("hello") }
      assert_match "Unknown generation provider", error.message
    end
  end
end
