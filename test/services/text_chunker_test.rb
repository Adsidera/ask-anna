require "test_helper"

class TextChunkerTest < ActiveSupport::TestCase
  test "starts a new chunk once a paragraph would push the buffer over max_words" do
    text = "First paragraph.\n\nSecond paragraph."

    chunks = TextChunker.call(text, max_words: 2, overlap_words: 0)

    assert_equal [ "First paragraph.", "Second paragraph." ], chunks
  end

  test "packs small paragraphs together up to max_words" do
    text = "one two three\n\nfour five six"

    chunks = TextChunker.call(text, max_words: 6, overlap_words: 2)

    assert_equal [ "one two three\n\nfour five six" ], chunks
  end

  test "starts a new chunk with overlap when the buffer would exceed max_words" do
    text = "one two three four five\n\nsix seven eight nine ten"

    chunks = TextChunker.call(text, max_words: 6, overlap_words: 2)

    assert_equal 2, chunks.size
    assert_equal "one two three four five", chunks[0]
    # the new chunk starts with the overlap tail of the previous one
    assert chunks[1].start_with?("four five")
    assert chunks[1].end_with?("six seven eight nine ten")
  end

  test "splits a single paragraph longer than max_words into overlapping windows" do
    words = (1..10).map(&:to_s)
    text = words.join(" ")

    chunks = TextChunker.call(text, max_words: 4, overlap_words: 1)

    assert_equal [ "1 2 3 4", "4 5 6 7", "7 8 9 10" ], chunks
  end

  test "flushes the buffered paragraphs before window-splitting a long paragraph" do
    text = "intro\n\n" + (1..10).map(&:to_s).join(" ")

    chunks = TextChunker.call(text, max_words: 4, overlap_words: 1)

    assert_equal [ "intro", "1 2 3 4", "4 5 6 7", "7 8 9 10" ], chunks
  end

  test "ignores blank paragraphs instead of producing an empty chunk" do
    text = "one\n\n\n\ntwo"

    chunks = TextChunker.call(text, max_words: 300, overlap_words: 40)

    assert_equal [ "one\n\ntwo" ], chunks
  end

  test "returns an empty array for blank text" do
    assert_equal [], TextChunker.call("")
    assert_equal [], TextChunker.call(nil)
  end
end
