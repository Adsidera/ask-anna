module Rag
  # Orchestrates the full /ask flow (spec Fase 2, AskController#create):
  # embed the question, retrieve the nearest chunks, build the grounded
  # prompt, generate an answer, run the grounding check, and log metrics.
  class QueryService
    RETRIEVAL_LIMIT = 5
    RELEVANCE_DISTANCE_THRESHOLD = ENV.fetch("RETRIEVAL_DISTANCE_THRESHOLD", 0.4).to_f

    SYSTEM_PROMPT = <<~PROMPT.strip
      Sei un assistente che risponde a domande sull'esperienza professionale di Anna,
      basandoti SOLO sul contesto fornito qui sotto. Se l'informazione non è presente
      nel contesto, rispondi che non hai informazioni su questo, senza inventare.
    PROMPT

    Result = Struct.new(:answer, :sources, keyword_init: true)

    def self.call(question)
      new(question).call
    end

    def initialize(question)
      @question = question
    end

    def call
      total_start = now

      question_vector, embedding_ms = timed { AI::EmbeddingClient.new.embed(@question) }
      chunks, retrieval_ms = timed { retrieve(question_vector) }
      raw_answer, generation_ms = timed { AI::GenerationClient.new.generate(build_prompt(chunks)) }
      grounded, grounding_ms = timed { GroundingChecker.call(answer: raw_answer, context_chunks: chunks.map(&:content)) }

      log(
        chunks: chunks,
        discarded_urls: grounded.discarded_urls,
        embedding_ms: embedding_ms,
        retrieval_ms: retrieval_ms,
        generation_ms: generation_ms,
        grounding_ms: grounding_ms,
        total_ms: elapsed_ms(total_start)
      )

      Result.new(
        answer: grounded.answer,
        sources: chunks.filter_map { |chunk| chunk.document.source_url }.uniq
      )
    end

    private

    def retrieve(question_vector)
      Chunk.nearest_neighbors(:embedding, question_vector, distance: "cosine")
        .includes(:document)
        .limit(RETRIEVAL_LIMIT)
        .to_a
    end

    def build_prompt(chunks)
      context = chunks.map.with_index(1) { |chunk, i| "[chunk #{i}]\n#{chunk.content}" }.join("\n\n")

      <<~PROMPT
        #{SYSTEM_PROMPT}

        Contesto:
        #{context}

        Domanda: #{@question}
      PROMPT
    end

    def log(chunks:, discarded_urls:, **timings)
      distances = chunks.map(&:neighbor_distance)
      low_relevance = distances.empty? || distances.min > RELEVANCE_DISTANCE_THRESHOLD

      Rails.logger.info(
        {
          event: "ask_query",
          question: @question,
          retrieved_chunk_ids: chunks.map(&:id),
          min_distance: distances.min,
          low_relevance: low_relevance,
          discarded_urls: discarded_urls
        }.merge(timings).to_json
      )
    end

    def timed
      start = now
      result = yield
      [ result, elapsed_ms(start) ]
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(start)
      ((now - start) * 1000).round(1)
    end
  end
end
