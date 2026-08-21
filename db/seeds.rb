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

puts "Seeded #{Document.count} documents, #{Chunk.count} chunks."
