# Ask Anna — Spec tecnico

## Obiettivo
Costruire un assistente conversazionale RAG (Retrieval-Augmented Generation) che risponde a domande sull'esperienza professionale di Anna Costalonga (esperienza Rails/backend, progetti, competenze), basandosi esclusivamente su contenuti pubblici forniti da lei (CV, post del blog, descrizioni progetti). Deployabile come popup su un sito personale.

Riferimento concettuale: [Ask Mauro](https://ai.maurogioberti.com) — SLM piccolo + retrieval rigoroso + grounding stretto sui link.

## Stack
- **Backend**: Ruby on Rails 8
- **Database**: PostgreSQL con estensione `pgvector`
- **Gemme principali**: `neighbor` (query vettoriali), `sidekiq` (job asincroni), `faraday` (chiamate HTTP verso servizi AI)
- **Modello di generazione**: Ollama + Qwen3 0.6B (self-hosted) in fase 1, con opzione di switch a Groq (Llama 3.x) per latenza minore
- **Modello di embedding**: API esterna (es. modello embedding di Groq/OpenAI) oppure modello locale leggero
- **Deploy target**: VPS Hetzner (Ubuntu 24.04), Nuremberg/Falkenstein
- **Esposizione pubblica**: Cloudflare Tunnel (no port forwarding)

## Fase 1 — Ingestion pipeline

### Modelli dati
```
Document
  - title:string
  - source_type:string   # "cv", "blog_post", "project", "talk"
  - source_url:string (opzionale)
  - raw_content:text
  - published_at:date
  - created_at / updated_at

Chunk
  - document_id:references
  - content:text
  - embedding:vector(N)   # N = dimensione del modello di embedding scelto
  - position:integer      # ordine del chunk nel documento originale
  - created_at / updated_at
```

### Migration chiave
- Abilitare l'estensione: `enable_extension "vector"`
- Colonna vettoriale su `chunks`: `t.vector :embedding, limit: N`
- Indice per query veloci: HNSW o IVFFlat su `embedding` (via `neighbor` o SQL diretto)

### Job di ingestion (Sidekiq)
`DocumentIngestionJob`
1. Riceve un `Document` appena creato/aggiornato
2. Spezza `raw_content` in chunk (per paragrafo, o a finestra fissa ~200-400 token con overlap ~50 token)
3. Per ogni chunk: chiama l'API di embedding, salva `Chunk` con vettore risultante
4. Gestione errori: retry su fallimento chiamata API, log su chunk non processati

### Requisiti funzionali fase 1
- CRUD per `Document` (admin-only, anche solo via Rails console/seed inizialmente, no serve UI complessa)
- Ri-processare un documento aggiornato deve invalidare/ricreare i suoi chunk esistenti
- Deve essere possibile ingest da: testo incollato diretto, o URL (fetch + strip HTML)

## Fase 2 — Query pipeline

### Endpoint
`POST /ask`
- Input: `{ question: string }`
- Output: `{ answer: string, sources: [url, ...] }` (streaming via Turbo Stream in versione avanzata)

### Flusso `AskController#create`
1. Validare/sanitizzare input (lunghezza minima/massima, rate limiting per IP)
2. Generare embedding della domanda (stessa API/modello usato in ingestion — **deve** essere lo stesso modello, non intercambiabile)
3. Retrieval: `Chunk.nearest_neighbors(:embedding, question_vector, distance: "cosine").limit(5)`
4. Costruire il prompt:
   ```
   Sei un assistente che risponde a domande sull'esperienza professionale di Anna,
   basandoti SOLO sul contesto fornito qui sotto. Se l'informazione non è presente
   nel contesto, rispondi che non hai informazioni su questo, senza inventare.

   Contesto:
   [chunk 1]
   [chunk 2]
   ...

   Domanda: [question]
   ```
5. Chiamare il modello di generazione (Ollama locale via HTTP a `localhost:11434/api/generate`, o Groq come alternativa)
6. **Grounding check** (post-processing, prima di ritornare la risposta):
   - Estrarre ogni URL presente nella risposta generata (regex)
   - Verificare che ogni URL compaia letteralmente in uno dei chunk usati come contesto
   - Se un URL non è verificato: rimuoverlo dalla risposta o sostituirlo con nota "fonte non verificata"
7. Loggare: domanda, chunk recuperati, risposta finale, latenza totale (per iterazione futura)

### Requisiti non funzionali
- Latenza percepita: usare streaming (Turbo Stream / Action Cable) per mostrare la risposta man mano che viene generata, anche se il modello impiega 2-4 secondi totali
- Rate limiting per evitare abuso (es. `rack-attack`, max N richieste/minuto per IP)
- Nessun dato personale sensibile nella knowledge base oltre a ciò che è già pubblico

## Fase 3 — Frontend / widget
- Popup JS minimale (no framework pesante necessario) integrabile via `<script>` su sito statico/Substack
- Textarea + submit + area risposta che si popola in streaming
- Mostra le fonti (`sources`) sotto la risposta come link cliccabili

## Fase 4 (opzionale, futura) — Interfaccia vocale
- STT: Whisper (self-hosted o API) per trascrivere la domanda vocale
- Generazione: stessa pipeline RAG di cui sopra, ma con chunking della risposta per frase (non aspettare la risposta completa)
- TTS: ElevenLabs (qualità alta, italiano ok) o Coqui TTS (self-hosted, gratuito) — sintesi frase-per-frase in parallelo alla generazione testuale
- Orchestrazione: Action Cable per il flusso bidirezionale audio/testo
- Avatar animato: fuori scope per la prima implementazione — valutare Ready Player Me + Three.js, o servizio managed (D-ID/HeyGen) solo dopo che la pipeline testuale+vocale funziona bene

## Deploy (VPS Hetzner)
1. Provisioning: Ubuntu 24.04, CPX31/CPX41
2. Setup: Postgres + estensione pgvector, Ruby/Rails, Ollama (`ollama pull qwen3:0.6b`)
3. Rails in produzione con Puma, servizio systemd per always-on
4. Cloudflare Tunnel per esposizione pubblica con HTTPS, collegato al dominio personale
5. Sidekiq come servizio systemd separato

## Metriche da tracciare (per iterazione)
- Latenza per fase (embedding, retrieval, generazione, grounding check)
- Domande per cui il retrieval non trova chunk sufficientemente rilevanti (soglia di distanza coseno) → segnala gap nella knowledge base
- Frequenza di URL scartati dal grounding check (indicatore di quanto "allucina" il modello)

## Note per Claude Code
- Iniziare da Fase 1 + Fase 2 (ingestion + query, senza streaming né voce)
- Testare prima in locale con Ollama su Docker/dev machine prima del deploy su VPS
- Usare seed data (2-3 documenti reali di Anna: CV, un post del blog, descrizione di un progetto) per validare il flusso end-to-end prima di aggiungere tutti i contenuti
