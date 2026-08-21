require "test_helper"

class AskControllerTest < ActionDispatch::IntegrationTest
  test "returns the answer and sources from Rag::QueryService" do
    fake_result = Rag::QueryService::Result.new(answer: "Anna works with Rails.", sources: [ "https://example.com/a" ])

    Rag::QueryService.stub(:call, fake_result) do
      post "/ask", params: { question: "What does Anna do?" }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Anna works with Rails.", body["answer"]
    assert_equal [ "https://example.com/a" ], body["sources"]
  end

  test "rejects a question that is too short" do
    post "/ask", params: { question: "hi" }, as: :json

    assert_response :unprocessable_content
    assert JSON.parse(response.body)["error"].present?
  end

  test "rejects a blank question" do
    post "/ask", params: { question: "" }, as: :json

    assert_response :unprocessable_content
  end

  test "rejects a question over the max length" do
    post "/ask", params: { question: "a" * 501 }, as: :json

    assert_response :unprocessable_content
  end

  test "returns 503 when the AI backend errors" do
    Rag::QueryService.stub(:call, ->(_question) { raise AI::GenerationClient::Error, "ollama down" }) do
      post "/ask", params: { question: "What does Anna do?" }, as: :json
    end

    assert_response :service_unavailable
  end

  test "rate limits requests per IP once the throttle is enabled" do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    fake_result = Rag::QueryService::Result.new(answer: "ok", sources: [])
    limit = ENV.fetch("ASK_RATE_LIMIT_PER_MINUTE", 10).to_i

    Rag::QueryService.stub(:call, fake_result) do
      limit.times do
        post "/ask", params: { question: "What does Anna do?" }, as: :json
        assert_response :success
      end

      post "/ask", params: { question: "What does Anna do?" }, as: :json
      assert_response :too_many_requests
    end
  ensure
    Rack::Attack.enabled = false
  end
end
