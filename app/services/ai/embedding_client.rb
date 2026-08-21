module AI
  # Generates embedding vectors for a piece of text.
  #
  # Must use the SAME provider/model at ingestion time and at query time --
  # embeddings from different models live in different vector spaces and
  # aren't comparable. The provider/model are read from ENV so both code
  # paths (DocumentIngestionJob and Rag::QueryService) stay in sync by
  # construction.
  class EmbeddingClient
    class Error < StandardError; end

    def initialize(
      provider: ENV.fetch("EMBEDDING_PROVIDER", "ollama"),
      model: ENV.fetch("EMBEDDING_MODEL", "nomic-embed-text")
    )
      @provider = provider
      @model = model
    end

    # text -> Array<Float>
    def embed(text)
      case @provider
      when "ollama"
        embed_via_ollama(text)
      when "openai", "groq"
        embed_via_openai_compatible(text)
      else
        raise Error, "Unknown embedding provider: #{@provider.inspect}"
      end
    rescue Faraday::Error => e
      # Covers connection-level failures (refused, timed out, DNS, ...) that
      # happen before there's an HTTP response to check .success? on -- e.g.
      # Ollama not running locally. Wrapped so callers only need to handle
      # AI::EmbeddingClient::Error, not know about Faraday internals.
      raise Error, "#{@provider} embedding request failed: #{e.message}"
    end

    private

    def embed_via_ollama(text)
      response = ollama_connection.post("/api/embeddings") do |req|
        req.body = { model: @model, prompt: text }
      end
      raise Error, "Ollama embedding request failed (#{response.status}): #{response.body}" unless response.success?

      embedding = response.body["embedding"]
      raise Error, "Ollama embedding response missing 'embedding': #{response.body}" if embedding.blank?

      embedding
    end

    def embed_via_openai_compatible(text)
      response = openai_compatible_connection.post("/embeddings") do |req|
        req.body = { model: @model, input: text }
      end
      unless response.success?
        raise Error, "#{@provider} embedding request failed (#{response.status}): #{response.body}"
      end

      embedding = response.body.dig("data", 0, "embedding")
      raise Error, "#{@provider} embedding response missing data[0].embedding: #{response.body}" if embedding.blank?

      embedding
    end

    def ollama_connection
      @ollama_connection ||= Faraday.new(url: ENV.fetch("OLLAMA_URL", "http://localhost:11434")) do |f|
        f.request :json
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        f.response :json
        f.options.timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    def openai_compatible_connection
      @openai_compatible_connection ||= Faraday.new(url: api_base_url) do |f|
        f.request :json
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        f.response :json
        f.headers["Authorization"] = "Bearer #{api_key}"
        f.options.timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    def api_base_url
      @provider == "groq" ? ENV.fetch("GROQ_API_URL", "https://api.groq.com/openai/v1") : ENV.fetch("OPENAI_API_URL", "https://api.openai.com/v1")
    end

    def api_key
      return ENV["EMBEDDING_API_KEY"] if ENV["EMBEDDING_API_KEY"].present?

      @provider == "groq" ? ENV["GROQ_API_KEY"] : ENV["OPENAI_API_KEY"]
    end
  end
end
