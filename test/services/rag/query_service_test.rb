require "test_helper"

class FakeEmbeddingClient
  def initialize(&block)
    @block = block
  end

  def embed(text)
    @block.call(text)
  end
end

class FakeGenerationClient
  def initialize(&block)
    @block = block
  end

  def generate(prompt)
    @block.call(prompt)
  end
end

module Rag
  class QueryServiceTest < ActiveSupport::TestCase
    setup do
      @dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i
    end

    test "retrieves nearest chunks, builds a grounded prompt, and strips unverified URLs" do
      doc_a = Document.create!(title: "A", source_type: "project", source_url: "https://example.com/a", raw_content: "content a")
      doc_b = Document.create!(title: "B", source_type: "project", source_url: "https://example.com/b", raw_content: "content b")

      chunk_a = doc_a.chunks.create!(content: "Anna built project A. See https://example.com/a.", position: 0, embedding: unit_vector(0))
      doc_b.chunks.create!(content: "Anna built project B.", position: 0, embedding: unit_vector(1))

      captured_prompt = nil
      fake_embedding_client = FakeEmbeddingClient.new { |_text| unit_vector(0) }
      fake_generation_client = FakeGenerationClient.new do |prompt|
        captured_prompt = prompt
        "Anna built project A. See https://example.com/a and https://made-up.example.com."
      end

      result = nil
      AI::EmbeddingClient.stub(:new, fake_embedding_client) do
        AI::GenerationClient.stub(:new, fake_generation_client) do
          result = Rag::QueryService.call("What did Anna build?")
        end
      end

      assert_includes captured_prompt, chunk_a.content
      assert_includes captured_prompt, "What did Anna build?"
      assert_equal "Anna built project A. See https://example.com/a and [fonte non verificata]", result.answer
      assert_equal [ "https://example.com/a", "https://example.com/b" ], result.sources
    end

    test "returns a canned no-info answer without contacting the embedding or generation model when there's nothing to work with" do
      # Fixture chunks and suggested questions exist but (like anything not
      # yet embedded) have no embedding, so nearest_neighbors would never
      # surface them either.
      assert_not Chunk.where.not(embedding: nil).exists?
      assert_not SuggestedQuestion.active.where.not(embedding: nil).exists?

      raise_if_called = ->(*) { raise "should not be called when there's nothing to work with" }

      result = nil
      AI::EmbeddingClient.stub(:new, raise_if_called) do
        AI::GenerationClient.stub(:new, raise_if_called) do
          result = Rag::QueryService.call("Anything at all?")
        end
      end

      assert_equal Rag::QueryService::NO_CONTEXT_ANSWER, result.answer
      assert_empty result.sources
    end

    test "matches a suggested question by embedding similarity and skips generation entirely" do
      suggested_question = SuggestedQuestion.create!(
        question: "What's the most exciting project you've worked on?",
        answer: "Curated answer about the project.",
        source_url: "https://example.com/project",
        embedding: unit_vector(0)
      )

      fake_embedding_client = FakeEmbeddingClient.new { |_text| unit_vector(0) }
      generation_should_not_be_called = ->(*) { raise "generation model should not be called on a suggested-question match" }

      result = nil
      AI::EmbeddingClient.stub(:new, fake_embedding_client) do
        AI::GenerationClient.stub(:new, generation_should_not_be_called) do
          result = Rag::QueryService.call("most exciting project?")
        end
      end

      assert_equal suggested_question.answer, result.answer
      assert_equal [ suggested_question.source_url ], result.sources
    end

    test "falls through to normal RAG when no suggested question is within the match threshold" do
      SuggestedQuestion.create!(question: "Unrelated question", answer: "Unrelated answer", embedding: unit_vector(5))

      document = Document.create!(title: "A", source_type: "project", raw_content: "content")
      document.chunks.create!(content: "Anna built project A.", position: 0, embedding: unit_vector(0))

      fake_embedding_client = FakeEmbeddingClient.new { |_text| unit_vector(0) }
      fake_generation_client = FakeGenerationClient.new { |_prompt| "Generated answer." }

      result = nil
      AI::EmbeddingClient.stub(:new, fake_embedding_client) do
        AI::GenerationClient.stub(:new, fake_generation_client) do
          result = Rag::QueryService.call("What did Anna build?")
        end
      end

      assert_equal "Generated answer.", result.answer
    end

    test "matches a suggested question even when there are no chunks at all" do
      suggested_question = SuggestedQuestion.create!(
        question: "What's your stack?", answer: "Rails and Postgres.", embedding: unit_vector(0)
      )

      fake_embedding_client = FakeEmbeddingClient.new { |_text| unit_vector(0) }
      generation_should_not_be_called = ->(*) { raise "generation model should not be called" }

      result = nil
      AI::EmbeddingClient.stub(:new, fake_embedding_client) do
        AI::GenerationClient.stub(:new, generation_should_not_be_called) do
          result = Rag::QueryService.call("What tech do you use?")
        end
      end

      assert_equal suggested_question.answer, result.answer
    end

    private

    def unit_vector(index)
      Array.new(@dimensions, 0.0).tap { |vector| vector[index] = 1.0 }
    end
  end
end
