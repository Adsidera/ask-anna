require "test_helper"

class FakeEmbeddingClient
  def initialize(&block)
    @block = block
  end

  def embed(text)
    @block.call(text)
  end
end

class DocumentIngestionJobTest < ActiveSupport::TestCase
  test "chunks the document and stores an embedding per chunk" do
    document = Document.new(title: "X", source_type: "cv", raw_content: "para one\n\npara two")
    document.save!(validate: false) # avoid the after_commit auto-enqueue firing a real embed call

    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i
    fake_embedding = Array.new(dimensions, 0.1)
    fake_client = FakeEmbeddingClient.new { |_text| fake_embedding }

    AI::EmbeddingClient.stub(:new, fake_client) do
      DocumentIngestionJob.perform_now(document.id)
    end

    expected_texts = TextChunker.call(document.raw_content)
    chunks = document.chunks.order(:position)
    assert_equal expected_texts, chunks.map(&:content)
    assert_equal (0...expected_texts.size).to_a, chunks.map(&:position)
    assert_equal fake_embedding, chunks.first.embedding
  end

  test "re-running the job invalidates and recreates existing chunks" do
    document = Document.new(title: "X", source_type: "cv", raw_content: "para one")
    document.save!(validate: false)

    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i
    fake_embedding = Array.new(dimensions, 0.1)
    fake_client = FakeEmbeddingClient.new { |_text| fake_embedding }

    AI::EmbeddingClient.stub(:new, fake_client) do
      DocumentIngestionJob.perform_now(document.id)
      old_chunk_id = document.chunks.first.id

      document.update_column(:raw_content, "brand new content")
      DocumentIngestionJob.perform_now(document.id)

      assert_equal 1, document.chunks.count
      assert_not_equal old_chunk_id, document.chunks.first.id
      assert_equal "brand new content", document.chunks.first.content
    end
  end

  test "logs and skips chunks whose embedding call keeps failing" do
    document = Document.new(title: "X", source_type: "cv", raw_content: "para one\n\npara two")
    document.save!(validate: false)

    call_count = 0
    fake_client = FakeEmbeddingClient.new do |_text|
      call_count += 1
      raise AI::EmbeddingClient::Error, "boom"
    end

    job = DocumentIngestionJob.new

    # Force two chunks regardless of how TextChunker happens to pack short
    # paragraphs, so we can assert retries are counted per chunk.
    TextChunker.stub(:call, [ "chunk 1", "chunk 2" ]) do
      AI::EmbeddingClient.stub(:new, fake_client) do
        job.stub(:sleep, nil) do
          job.perform(document.id)
        end
      end
    end

    assert_equal 0, document.chunks.count
    assert_equal DocumentIngestionJob::MAX_EMBEDDING_ATTEMPTS * 2, call_count
  end
end
