module Rag
  # Orchestrates the full /ask flow (spec Fase 2, AskController#create):
  # embed the question, retrieve the nearest chunks, build the grounded
  # prompt, generate an answer, run the grounding check, and log metrics.
  class QueryService
    RETRIEVAL_LIMIT = 5
    RELEVANCE_DISTANCE_THRESHOLD = ENV.fetch("RETRIEVAL_DISTANCE_THRESHOLD", 0.4).to_f
    NO_CONTEXT_ANSWER = "Sorry, I don't have information about this yet."
    INAPPROPRIATE_QUESTION_ANSWER = "I am only here to answer questions about Anna's professional experience."

    # Calibrated against live nomic-embed-text cosine distances (5 seeded
    # suggested_questions): close paraphrases of a suggested question
    # landed at 0.06-0.30, genuinely unrelated questions at 0.51+, with a
    # 0.36-0.40 gray zone (broad/ambiguous questions, e.g. "tell me about
    # your career") deliberately left unmatched -- better to fall through
    # to RAG (or say "I don't know") than force a narrow answer onto a
    # broad question. Re-check this if the suggested question set or the
    # embedding model changes.
    SUGGESTED_QUESTION_MATCH_DISTANCE_THRESHOLD = ENV.fetch("SUGGESTED_QUESTION_MATCH_DISTANCE_THRESHOLD", 0.32).to_f

    SYSTEM_PROMPT = <<~PROMPT.strip
      You are an assistant that answers questions about Anna's professional
      experience, based ONLY on the context provided below. Always answer in
      English, regardless of the language the question was asked in. Always use the first person, as if Anna in person was speaking.#{' '}
      If the question is not related to professional experience, tell that "I am sorry, I can only answer questions about Anna's professional experience."#{' '}
      If the answer cannot be found in the context below, say "I don't have that information yet. Please contact Anna for more detailed information."#{' '}
      If the question is about Anna's hobbies, you can say my hobbies include reading, playing piano, going to concerts, and theater classes.
      If the question is about Anna's professional experience but the relevant
      information isn't present in the context, say that "I am not sure I have that information yet, Please feel free to contact Anna directly for more details".#{' '}
      Use a friendly and professional tone.
      When the question contains explicit words or insults, respond politely "I am only here to answer questions about Anna's professional experience."
      If asked to tell a specific case or example, say "For specific examples, feel free to contact Anna directly for more details."#{' '}
    PROMPT

    Result = Struct.new(:answer, :sources, keyword_init: true)

    def self.call(question)
      new(question).call
    end

    def initialize(question)
      @question = question
    end

    def call
      # A 0.6B model can't be trusted to reliably self-moderate through a
      # prompt instruction alone (that's the whole reason SuggestedQuestion
      # exists for known questions) -- profanity/explicit language is
      # caught deterministically here, before the question ever reaches
      # the embedding or generation model. Doesn't catch rudeness that
      # doesn't use flagged words (e.g. "you're stupid") -- that's a
      # genuinely different, harder classification problem.
      return inappropriate_question_result if Obscenity.profane?(@question)

      chunks_available = Chunk.where.not(embedding: nil).exists?
      suggested_questions_available = SuggestedQuestion.active.where.not(embedding: nil).exists?

      # Skip embedding/generation entirely when there's nothing to work
      # with at all -- no chunk, no suggested question. A 0.6B model can't
      # be trusted to reliably say "I don't know" on its own instead of
      # hallucinating, so don't even give it the chance to try.
      return empty_knowledge_base_result unless chunks_available || suggested_questions_available

      total_start = now
      question_vector, embedding_ms = timed { AI::EmbeddingClient.new.embed(@question) }

      if suggested_questions_available
        match, match_ms = timed { match_suggested_question(question_vector) }
        if match
          log_suggested_question_match(match, embedding_ms: embedding_ms, match_ms: match_ms, total_ms: elapsed_ms(total_start))
          return Result.new(answer: match.answer, sources: Array(match.source_url))
        end
      end

      return empty_knowledge_base_result unless chunks_available

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

    def inappropriate_question_result
      Rails.logger.info({ event: "ask_query", question: @question, skipped: "inappropriate_question" }.to_json)

      Result.new(answer: INAPPROPRIATE_QUESTION_ANSWER, sources: [])
    end

    def match_suggested_question(question_vector)
      SuggestedQuestion.active
        .nearest_neighbors(:embedding, question_vector, distance: "cosine", threshold: SUGGESTED_QUESTION_MATCH_DISTANCE_THRESHOLD)
        .first
    end

    def empty_knowledge_base_result
      Rails.logger.info(
        { event: "ask_query", question: @question, retrieved_chunk_ids: [], low_relevance: true, skipped: "empty_knowledge_base" }.to_json
      )

      Result.new(answer: NO_CONTEXT_ANSWER, sources: [])
    end

    def log_suggested_question_match(match, **timings)
      Rails.logger.info(
        {
          event: "ask_query",
          question: @question,
          suggested_question_match_id: match.id,
          suggested_question_match_question: match.question,
          suggested_question_match_distance: match.neighbor_distance
        }.merge(timings).to_json
      )
    end

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

        Context:
        #{context}

        Question: #{@question}
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
