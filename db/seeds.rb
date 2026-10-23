# Seed data to validate the end-to-end flow (ingestion + query) locally,
# as suggested in the spec ("Note per Claude Code").
#
# Content comes from db/seeds/content.yml (gitignored: it holds the real,
# personal texts), falling back to the committed placeholders in
# db/seeds/content.example.yml. Records are upserted by title/question, so
# re-running `bin/rails db:seed` after editing the YAML updates them.
#
# Requires Ollama running locally with the embedding model already
# pulled, e.g.: `ollama pull nomic-embed-text`
#
# Ingestion jobs run synchronously during seeding, so Sidekiq/Redis don't
# need to be running just to populate test data.
ActiveJob::Base.queue_adapter = :inline

content_path = Rails.root.join("db/seeds/content.yml")
content_path = Rails.root.join("db/seeds/content.example.yml") unless content_path.exist?
content = YAML.safe_load_file(content_path, permitted_classes: [ Date ])

content.fetch("documents").each do |attrs|
  document = Document.find_or_initialize_by(title: attrs["title"], source_type: attrs["source_type"])
  document.update!(attrs.slice("source_url", "published_at", "raw_content"))
end

# Top questions developers/recruiters tend to ask, with hand-curated
# answers so they don't depend on the small local model synthesizing a
# coherent answer from raw chunks every time (see Rag::QueryService).
content.fetch("suggested_questions").each do |attrs|
  suggested_question = SuggestedQuestion.find_or_initialize_by(question: attrs["question"])
  suggested_question.update!(answer: attrs["answer"], active: true)
end

puts "Seeded from #{content_path.basename}: #{Document.count} documents, #{Chunk.count} chunks, #{SuggestedQuestion.count} suggested questions."
