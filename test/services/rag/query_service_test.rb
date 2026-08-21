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

    test "returns no sources when no chunks are retrieved" do
      fake_embedding_client = FakeEmbeddingClient.new { |_text| unit_vector(0) }
      fake_generation_client = FakeGenerationClient.new { |_prompt| "I don't have information about this." }

      result = nil
      AI::EmbeddingClient.stub(:new, fake_embedding_client) do
        AI::GenerationClient.stub(:new, fake_generation_client) do
          result = Rag::QueryService.call("Anything at all?")
        end
      end

      assert_equal "I don't have information about this.", result.answer
      assert_empty result.sources
    end

    private

    def unit_vector(index)
      Array.new(@dimensions, 0.0).tap { |vector| vector[index] = 1.0 }
    end
  end
end
