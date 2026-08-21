require "test_helper"

class ChunkTest < ActiveSupport::TestCase
  test "invalid without content" do
    chunk = Chunk.new(document: documents(:cv), position: 5)
    assert_not chunk.valid?
    assert_includes chunk.errors[:content], "can't be blank"
  end

  test "invalid without position" do
    chunk = Chunk.new(document: documents(:cv), content: "text")
    assert_not chunk.valid?
    assert_includes chunk.errors[:position], "can't be blank"
  end

  test "position must be unique within a document" do
    document = documents(:cv)
    existing = chunks(:cv_chunk_one)
    chunk = Chunk.new(document: document, content: "other", position: existing.position)

    assert_not chunk.valid?
    assert_includes chunk.errors[:position], "has already been taken"
  end

  test "the same position is allowed across different documents" do
    chunk = Chunk.new(
      document: documents(:blog_post),
      content: "other",
      position: chunks(:cv_chunk_one).position
    )

    assert chunk.valid?
  end

  test "nearest_neighbors orders chunks by cosine distance to the query vector" do
    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i
    document = documents(:cv)

    near = document.chunks.create!(content: "near", position: 90, embedding: unit_vector(dimensions, 0))
    far = document.chunks.create!(content: "far", position: 91, embedding: unit_vector(dimensions, 1))

    results = Chunk.nearest_neighbors(:embedding, unit_vector(dimensions, 0), distance: "cosine")
      .where(id: [ near.id, far.id ])
      .to_a

    assert_equal [ near, far ], results
  end

  private

  def unit_vector(dimensions, index)
    Array.new(dimensions, 0.0).tap { |vector| vector[index] = 1.0 }
  end
end
