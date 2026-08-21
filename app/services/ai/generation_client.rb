module AI
  # Calls the generation (chat/completion) model: Ollama locally by default,
  # or Groq as a lower-latency alternative (spec section "Stack").
  class GenerationClient
    class Error < StandardError; end

    def initialize(
      provider: ENV.fetch("GENERATION_PROVIDER", "ollama"),
      model: ENV.fetch("GENERATION_MODEL", "qwen3:0.6b")
    )
      @provider = provider
      @model = model
    end

    # prompt -> String (full response, no streaming)
    def generate(prompt)
      case @provider
      when "ollama"
        generate_via_ollama(prompt)
      when "groq"
        generate_via_groq(prompt)
      else
        raise Error, "Unknown generation provider: #{@provider.inspect}"
      end
    end

    private

    def generate_via_ollama(prompt)
      response = ollama_connection.post("/api/generate") do |req|
        req.body = { model: @model, prompt: prompt, stream: false }
      end
      raise Error, "Ollama generation request failed (#{response.status}): #{response.body}" unless response.success?

      text = response.body["response"]
      raise Error, "Ollama generation response missing 'response': #{response.body}" if text.nil?

      text
    end

    def generate_via_groq(prompt)
      response = groq_connection.post("/chat/completions") do |req|
        req.body = {
          model: @model,
          messages: [ { role: "user", content: prompt } ]
        }
      end
      raise Error, "Groq generation request failed (#{response.status}): #{response.body}" unless response.success?

      text = response.body.dig("choices", 0, "message", "content")
      raise Error, "Groq generation response missing choices[0].message.content: #{response.body}" if text.nil?

      text
    end

    def ollama_connection
      @ollama_connection ||= Faraday.new(url: ENV.fetch("OLLAMA_URL", "http://localhost:11434")) do |f|
        f.request :json
        f.response :json
        f.options.timeout = 60
        f.adapter Faraday.default_adapter
      end
    end

    def groq_connection
      @groq_connection ||= Faraday.new(url: ENV.fetch("GROQ_API_URL", "https://api.groq.com/openai/v1")) do |f|
        f.request :json
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        f.response :json
        f.headers["Authorization"] = "Bearer #{ENV["GENERATION_API_KEY"].presence || ENV["GROQ_API_KEY"]}"
        f.options.timeout = 30
        f.adapter Faraday.default_adapter
      end
    end
  end
end
