# Seed data to validate the end-to-end flow (ingestion + query) locally,
# as suggested in the spec ("Note per Claude Code").
#
# Placeholder: replace raw_content with the real texts (CV, blog post,
# project description) before using this in production.
#
# Requires Ollama running locally with the embedding model already
# pulled, e.g.: `ollama pull nomic-embed-text`
#
# Ingestion jobs run synchronously during seeding, so Sidekiq/Redis don't
# need to be running just to populate test data.
ActiveJob::Base.queue_adapter = :inline

cv = Document.find_or_create_by!(title: "CV — Anna Costalonga", source_type: "cv") do |doc|
  doc.source_url = nil
  doc.published_at = Date.new(2026, 1, 1)
  doc.raw_content = <<~TEXT
    Anna Costalonga is a software engineer specialized in Ruby on Rails backend
    development.

    Professional experience:
    Building production Rails applications, with a focus on data modeling,
    integrations with external APIs, background jobs, and
    authentication/authorization. Comfortable with PostgreSQL, testing
    (RSpec/Minitest), and code review.

    Technical skills:
    Ruby, Ruby on Rails, PostgreSQL, Sidekiq, RSpec, Git, VPS and cloud
    deployment, integrating AI services (embeddings, LLMs via API).

    [PLACEHOLDER: replace with Anna's real CV]
  TEXT
end

blog_post = Document.find_or_create_by!(title: "Why I built Ask Anna", source_type: "blog_post") do |doc|
  doc.source_url = "https://annacostalonga.example.com/blog/ask-anna"
  doc.published_at = Date.new(2026, 6, 1)
  doc.raw_content = <<~TEXT
    I built Ask Anna, a RAG assistant that answers questions about my
    professional experience based only on public content I wrote myself: CV,
    blog posts, project descriptions.

    The goal is to have a small model (Qwen3 0.6B via Ollama) with rigorous
    retrieval and strict grounding on links, so it doesn't invent sources that
    don't exist. It's inspired by Ask Mauro (https://ai.maurogioberti.com).

    [PLACEHOLDER: replace with a real blog post from Anna]
  TEXT
end

project = Document.find_or_create_by!(title: "Project: Ask Anna", source_type: "project") do |doc|
  doc.source_url = "https://github.com/anna/ask-anna"
  doc.published_at = Date.new(2026, 8, 1)
  doc.raw_content = <<~TEXT
    Ask Anna is a conversational RAG assistant built with Ruby on Rails 8,
    PostgreSQL with the pgvector extension for vector search, Sidekiq for
    asynchronous document ingestion, and Ollama with Qwen3 0.6B as the
    self-hosted generation model.

    The flow: documents are split into chunks, each chunk is turned into an
    embedding and stored; user questions are compared via cosine similarity
    against the most relevant chunks, which become the context for the
    generation model. A grounding-check step strips any URL in the answer
    that doesn't literally appear in the retrieved context.

    [PLACEHOLDER: replace with the real project description]
  TEXT
end


# Top 5 questions developers/recruiters tend to ask, with hand-curated
# answers so they don't depend on the small local model synthesizing a
# coherent answer from raw chunks every time (see Rag::QueryService).
suggested_questions = [
  {
    question: "What's the most exciting project you've worked on?",
    answer: <<~TEXT.strip
      The most exciting project I've worked on is Xikolo, the Rails-based platform powering openHPI and openWHO —
      the World Health Organization's e-learning portal. It's built as a service-oriented architecture using
      domain-driven design: separate services per bounded context (account, course, pinboard, lti, notification,
      and more) rather than strict microservices. Getting to make real architecture decisions on a system serving
      WHO's global health education was genuinely one of the most rewarding parts of my career so far.
    TEXT
  },
  {
    question: "What's your tech stack?",
    answer: <<~TEXT.strip
      My core stack is Ruby on Rails, with RabbitMQ for pub-sub messaging between services, Redis and Sidekiq
      (previously also DelayedJob) for async job processing, advanced PostgreSQL, and AWS for infrastructure.
      Lately I've also been building personal AI/RAG projects — this app included — with Rails 8, pgvector,
      FastAPI, LangChain, and Groq/Ollama for local and API-based LLM inference.
    TEXT
  },
  {
    question: "How many years of experience do you have?",
    answer: <<~TEXT.strip
      I have about 8 years of backend development experience. I transitioned into software engineering in 2016
      through the CareerFoundry bootcamp, worked as a freelancer, took a pause during COVID, and then spent
      2021–2024 as a senior backend developer at HPI working on Xikolo.
    TEXT
  },
  {
    question: "Are you open to new opportunities right now?",
    answer: <<~TEXT.strip
      Yes — I'm currently between roles and actively job searching. I'm open to Rails/backend developer
      positions, SRE/application maintenance roles, and technical support roles, and I'm looking across several
      European markets: Germany, France, Spain, Italy.
    TEXT
  },
  {
    question: "What kind of role or work do you enjoy most?",
    answer: <<~TEXT.strip
      I'm most drawn to backend Rails roles with a strong architecture and design component — service-oriented
      systems, domain-driven design, that kind of thing. I'm also increasingly interested in work that blends
      backend engineering with AI/ML, which is part of why I've been building projects like this one.
    TEXT
  }
]

suggested_questions.each do |attrs|
  SuggestedQuestion.find_or_create_by!(question: attrs[:question]) do |suggested_question|
    suggested_question.answer = attrs[:answer]
    suggested_question.active = true
  end
end

puts "Seeded #{Document.count} documents, #{Chunk.count} chunks, #{SuggestedQuestion.count} suggested questions."
