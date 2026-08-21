require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    document = Document.new(title: "Talk", source_type: "talk", raw_content: "content")
    assert document.valid?
  end

  test "invalid without a title" do
    document = Document.new(source_type: "cv", raw_content: "content")
    assert_not document.valid?
    assert_includes document.errors[:title], "can't be blank"
  end

  test "invalid with an unknown source_type" do
    document = Document.new(title: "X", source_type: "tweet", raw_content: "content")
    assert_not document.valid?
    assert_includes document.errors[:source_type], "is not included in the list"
  end

  test "invalid with a malformed source_url" do
    document = Document.new(title: "X", source_type: "cv", raw_content: "content", source_url: "not a url")
    assert_not document.valid?
    assert_includes document.errors[:source_url], "is invalid"
  end

  test "blank source_url is allowed" do
    document = Document.new(title: "X", source_type: "cv", raw_content: "content", source_url: "")
    assert document.valid?
  end

  test "destroying a document destroys its chunks" do
    document = documents(:cv)
    chunk_count = document.chunks.count

    assert_difference -> { Chunk.count }, -chunk_count do
      document.destroy
    end
  end

  test "creating a document enqueues DocumentIngestionJob" do
    assert_enqueued_with(job: DocumentIngestionJob) do
      Document.create!(title: "New", source_type: "cv", raw_content: "some content")
    end
  end

  test "updating raw_content re-enqueues DocumentIngestionJob" do
    document = documents(:cv)

    assert_enqueued_with(job: DocumentIngestionJob, args: [ document.id ]) do
      document.update!(raw_content: "updated content")
    end
  end

  test "updating an unrelated attribute does not enqueue DocumentIngestionJob" do
    document = documents(:cv)

    assert_no_enqueued_jobs only: DocumentIngestionJob do
      document.update!(title: "New title")
    end
  end

  test "ingest_from_url! fetches, strips HTML, and creates a document" do
    HtmlFetcher.stub(:fetch_text, "plain text body") do
      document = Document.ingest_from_url!(url: "https://example.com/post", title: "Post", source_type: "blog_post")

      assert document.persisted?
      assert_equal "plain text body", document.raw_content
      assert_equal "https://example.com/post", document.source_url
    end
  end
end
