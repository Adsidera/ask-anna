# Splits a document's raw text into chunks for embedding, per spec:
# "per paragrafo, o a finestra fissa ~200-400 token con overlap ~50 token".
#
# Uses paragraphs as the natural unit, packing them into ~300-word chunks
# (approximating 200-400 tokens) with a ~40-word overlap between
# consecutive chunks (approximating ~50 tokens) so retrieval doesn't lose
# context at chunk boundaries. A single paragraph longer than the target
# size is itself split into overlapping fixed windows.
class TextChunker
  DEFAULT_MAX_WORDS = 300
  DEFAULT_OVERLAP_WORDS = 40

  def self.call(text, max_words: DEFAULT_MAX_WORDS, overlap_words: DEFAULT_OVERLAP_WORDS)
    new(text, max_words: max_words, overlap_words: overlap_words).call
  end

  def initialize(text, max_words: DEFAULT_MAX_WORDS, overlap_words: DEFAULT_OVERLAP_WORDS)
    @paragraphs = text.to_s.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
    @max_words = max_words
    @overlap_words = overlap_words
  end

  # Returns an Array<String>, one entry per chunk, in document order.
  def call
    chunks = []
    buffer = []

    @paragraphs.each do |paragraph|
      words = paragraph.split(/\s+/)

      if words.size > @max_words
        flush(chunks, buffer)
        buffer = []
        chunks.concat(window_split(words))
        next
      end

      if buffer.any? && word_count(buffer) + words.size > @max_words
        flush(chunks, buffer)
        buffer = overlap_tail(buffer)
      end

      buffer << paragraph
    end

    flush(chunks, buffer)
    chunks
  end

  private

  def word_count(buffer)
    buffer.sum { |paragraph| paragraph.split(/\s+/).size }
  end

  def flush(chunks, buffer)
    return if buffer.empty?

    chunks << buffer.join("\n\n")
  end

  def overlap_tail(buffer)
    tail = buffer.join(" ").split(/\s+/).last(@overlap_words)
    tail.empty? ? [] : [ tail.join(" ") ]
  end

  def window_split(words)
    windows = []
    step = @max_words - @overlap_words
    i = 0

    loop do
      windows << words[i, @max_words].join(" ")
      break if i + @max_words >= words.size

      i += step
    end

    windows
  end
end
