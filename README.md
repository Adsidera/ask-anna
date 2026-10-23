# Ask Anna

RAG assistant that answers questions about Anna Costalonga's professional
experience, grounded strictly in her own public content (CV, blog posts,
project descriptions). See [ask-anna-spec.md](ask-anna-spec.md) for the
full spec this implements (Fase 1 + Fase 2, per the spec's own "Note per
Claude Code").

## Stack

- Ruby on Rails 8, PostgreSQL + `pgvector` (via the `neighbor` gem)
- Sidekiq for async document ingestion, Faraday for HTTP calls to
  Ollama/Groq/OpenAI-compatible APIs
- Generation: Ollama + Qwen3 0.6B locally by default, Groq as a
  lower-latency alternative
- Embeddings: Ollama (`nomic-embed-text`) by default, or an OpenAI/Groq
  embeddings API
- Widget (Fase 3): TypeScript (`app/frontend/widget.ts`), compiled to a
  single `public/widget.js`, no framework

## Local setup

Requirements: PostgreSQL with the `vector` extension available, Redis,
[Ollama](https://ollama.com), Node (only to build the widget). On macOS:

```
brew install redis && brew services start redis   # Sidekiq needs this running
brew install ollama
```

```
bundle install
cp .env.example .env        # adjust if needed; defaults assume Ollama locally
             # also set ADMIN_USERNAME/ADMIN_PASSWORD in .env to use /admin
ollama pull qwen3:0.6b
ollama pull nomic-embed-text
bin/rails db:create db:migrate
bin/rails db:seed           # loads 2-3 placeholder documents, see db/seeds.rb
```

Run the app:

```
bin/rails server             # http://localhost:3000
bundle exec sidekiq           # in a separate terminal, for async ingestion
```

`db:seed` runs ingestion inline (no Sidekiq needed) so you can validate the
end-to-end flow immediately; new/updated `Document`s created afterwards go
through `DocumentIngestionJob` via Sidekiq as normal.

### Ask a question

```
curl -X POST localhost:3000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What backend experience does Anna have?"}'
```

### Ingest a document

Fase 1 is admin-only (spec). Two ways in:

**Admin panel** at `/admin` (HTTP Basic Auth — set `ADMIN_USERNAME`/
`ADMIN_PASSWORD` in `.env`, unset means the panel 503s rather than opening
with a guessable default). Create a document by pasting text, giving a
source URL (fetched + HTML-stripped), or uploading a PDF (text-extracted) —
whichever one you fill in wins, in that priority order.

**Rails console**, for scripting/seeding:

```ruby
# pasted text
Document.create!(title: "CV", source_type: "cv", raw_content: "...")

# from a URL (fetches + strips HTML)
Document.ingest_from_url!(url: "https://...", title: "Blog post", source_type: "blog_post")
```

Either way, updating `raw_content` on an existing `Document` automatically
invalidates and re-creates its chunks (`app/models/document.rb`).

### Suggested questions

The small local generation model is unreliable at synthesizing answers to
the questions people ask most (see `Rag::QueryService`). `SuggestedQuestion`
records (managed at `/admin/suggested_questions`, seeded with the top 5 in
`db/seeds.rb`) hold a hand-curated answer per question; when an incoming
question's embedding is close enough (cosine distance below
`SUGGESTED_QUESTION_MATCH_DISTANCE_THRESHOLD`, default `0.32`, calibrated
against live `nomic-embed-text` distances -- see the comment on that
constant) to one of them, that answer is returned directly and the
generation model is never called. They're also shown as clickable chips on
the homepage and widget. `GET /suggested_questions` exposes the question
text (not answers) for the widget to fetch.

## Widget (Fase 3)

Source: `app/frontend/widget.ts`. Rebuild after editing:

```
npm install
npm run build      # -> public/widget.js
```

Embed on any site:

```html
<script src="https://your-ask-anna-host/widget.js" data-api-base="https://your-ask-anna-host" defer></script>
```

Set `ALLOWED_ORIGINS` (see `.env.example`) to the embedding site's origin
so CORS allows the cross-origin `POST /ask` call.

## Tests

```
bin/rails test
bin/rubocop
bin/brakeman
```

AI calls (embedding/generation) are stubbed in tests — no Ollama/Redis
required to run the suite.
