# Post-processing safety net (spec Fase 2, step 6): strips any URL the
# model invented that doesn't literally appear in the retrieved context,
# since the generation model can hallucinate links even when instructed
# not to.
class GroundingChecker
  URL_REGEX = %r{https?://[^\s\)\]\}>,"']+}

  Result = Struct.new(:answer, :verified_sources, :discarded_urls, keyword_init: true)

  def self.call(answer:, context_chunks:)
    new(answer: answer, context_chunks: context_chunks).call
  end

  def initialize(answer:, context_chunks:)
    @answer = answer.to_s
    @context_text = context_chunks.join("\n")
  end

  def call
    verified = []
    discarded = []

    cleaned_answer = @answer.gsub(URL_REGEX) do |url|
      trimmed = url.sub(/[.,;:!?]+\z/, "")

      if @context_text.include?(trimmed)
        verified << trimmed
        url
      else
        discarded << trimmed
        "[fonte non verificata]"
      end
    end

    Result.new(answer: cleaned_answer, verified_sources: verified.uniq, discarded_urls: discarded.uniq)
  end
end
