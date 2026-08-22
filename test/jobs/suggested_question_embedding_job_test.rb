require "test_helper"

class SuggestedQuestionEmbeddingJobTest < ActiveSupport::TestCase
  test "embeds the question and stores the vector" do
    suggested_question = suggested_questions(:most_exciting_project)
    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i
    fake_embedding = Array.new(dimensions, 0.2)

    fake_client = Object.new
    fake_client.define_singleton_method(:embed) { |_text| fake_embedding }

    AI::EmbeddingClient.stub(:new, fake_client) do
      SuggestedQuestionEmbeddingJob.perform_now(suggested_question.id)
    end

    assert_equal fake_embedding, suggested_question.reload.embedding
  end
end
