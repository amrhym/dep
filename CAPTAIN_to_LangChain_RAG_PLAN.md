# Migration Plan: Replace “Captain” with LangChain + RAG

Owner: DEP Team
Status: Draft (Planning only)
Target branches: feature/rag-migration (behind feature flag)

## Context and scope

This repository includes a first‑party AI assistant subsystem under the “Captain” namespace used across backend (Ruby) and frontend (Vue) to power copilot/assistant features.

Key anchor points identified via code search:
- Backend services/controllers (Ruby):
  - enterprise/app/services/captain/** (agent_runner_service.rb, llm/*, tools/*, …)
  - enterprise/app/controllers/api/v1/accounts/captain/** (assistant_responses_controller.rb, documents_controller.rb, …)
  - enterprise/lib/captain/** (llm_service.rb, prompts, tool runtime, response schema, …)
  - enterprise/app/jobs/captain/** (response builders, crawlers, embeddings)
  - enterprise/app/models/captain/** (assistant, document, scenario, inbox, response)
  - lib/integrations/captain/processor_service.rb
- Frontend (Vue):
  - app/javascript/dashboard/components-next/captain/** and routes under app/javascript/dashboard/routes/dashboard/captain/**
  - store modules under app/javascript/dashboard/store/captain/**
- Data model and migrations: db/migrate/*captain* and related schema entries
- Existing embeddings: enterprise/app/models/article_embedding.rb
- Tool configuration: config/agents/tools.yml

Goal: Replace “Captain”’s runtime with a LangChain-based RAG service while preserving the outward API that the UI and internal consumers rely on. We will ship behind a feature flag and allow a runtime fallback to Captain until stabilized.

## Objectives and non‑goals

Objectives
- Introduce a dedicated RAG service (LangChain + vector store) with clear HTTP/gRPC boundaries.
- Reuse our existing Postgres + pgvector for embeddings (already part of docker-compose).
- Keep Chatwoot/DEP’s HTTP APIs stable; frontend changes should be minimal or none.
- Provide a safe migration path for existing Captain documents, assistants, and responses.
- Improve retrieval quality, latency, and observability.

Non‑goals
- Large UI rewrites. We adapt the backend first and keep the current UX.
- Changing account/billing semantics tied to assistant usage (out of scope for v1).

## Proposed architecture (high level)

- New microservice: rag-service (Python, FastAPI) using LangChain (and optional LangGraph for orchestration).
- Vector store: Postgres (pgvector) — reuse our existing postgres service (compose already uses pgvector/pgvector:pg16).
- Embeddings: pluggable provider via ENV (default: OpenAI text-embedding-3-large; alt: Voyage, Cohere, local models), stored in pgvector.
- Rerank (optional): Cohere Rerank or bge-reranker-small as an optimization layer (feature‑flagged).
- Caching: Redis (reuse dep-redis) for request dedupe and doc ETL state.
- Ingestion connectors: initial support for uploaded files + basic web crawler (Firecrawl parity later), with background indexing via Sidekiq triggers.
- Security: service-to-service HMAC header; service bound to internal network only.

### Service boundary

Backend (Ruby) calls rag-service instead of Captain’s Ruby LLM stack. We introduce a small adapter client to translate existing Captain payloads to the new service contract.

```yaml path=null start=null
# New docker-compose fragment (to be added later)
services:
  rag-service:
    build: ./services/rag-service
    environment:
      - RAG_DB_URL=${RAG_DB_URL:-postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/rag}
      - RAG_EMBEDDINGS_PROVIDER=openai
      - RAG_OPENAI_API_KEY=${OPENAI_API_KEY}
      - RAG_VECTOR_SCHEMA=rag
      - RAG_AUTH_HMAC_KEY=${RAG_AUTH_HMAC_KEY}
    depends_on:
      - postgres
      - redis
    networks:
      - default
    ports: [] # internal only
```

### rag-service endpoints (initial)

- POST /v1/generate
  - Input: { conversation, messages[], assistant_config, retrieval: { top_k, filters }, streaming:true|false }
  - Output: { answer, citations[], usage, trace } (SSE if streaming)
- POST /v1/index
  - Input: { source: upload|url|html, metadata, chunking, pipeline: { embedder, split }, upsert: bool }
  - Output: { document_id, chunks, status }
- GET /v1/search
  - Input: { query, filters, top_k }
  - Output: { hits: [ { chunk_id, text, score, metadata } ] }

### Vector schema (pgvector)

- rag.documents(id, external_id, account_id, source_type, source_uri, metadata jsonb, created_at)
- rag.chunks(id, document_id, position, text, metadata jsonb)
- rag.embeddings(id, chunk_id, embedding vector(1536), model, created_at)
- rag.indices(materialized views or secondary tables for filters; optional)

## Integration plan (server-side)

1) Add a Ruby adapter client
- New class: Rag::Client (Faraday/HTTPX) with HMAC auth, retry, timeouts.
- Methods: generate(payload), index(payload), search(payload).
- Feature flag (e.g., features.yml + ENV FEATURE_RAG_ENABLED) toggles Captain vs Rag.

2) Replace Captain LLM calls with Rag::Client
- enterprise/lib/captain/llm_service.rb → wrap; if flag on, call Rag::Client.generate.
- enterprise/app/services/captain/assistant/agent_runner_service.rb → swap tool‑driven thoughts generation to use Rag retrieval + tool calls via webhooks (see Tools below).
- enterprise/app/jobs/captain/**response** → route to Rag for answer synthesis.

3) Tools interoperability
- Current Captain tools (add_private_note_tool.rb, add_label_to_conversation_tool.rb, etc.) become HTTP webhooks that rag-service can invoke as LangChain Tools.
- Define a tool registry manifest exposed by Chatwoot (signed) so rag-service knows available tools per account.
- Tool invocation flow: rag-service → POST /internal/tools/execute with {tool, args} → Chatwoot executes and responds.

4) Documents and ingestion
- Keep existing Captain documents API surface stable.
- Controller calls Rag::Client.index.
- Background: Sidekiq jobs that today run Captain::Documents::* will enqueue a rag index job and poll status.

5) Streaming responses
- Maintain streaming to the frontend via existing endpoints (SSE/ActionCable). Backend streams what rag-service emits.

6) Data compatibility and migration
- Map Captain::Document → rag.documents (store captain document id as external_id).
- Re-embed existing content incrementally; backfill job with rate limits.
- Keep Captain tables for rollback window; schedule cleanup in v2.

## Integration plan (frontend)

- No route changes. Captain UI continues to hit the same REST endpoints.
- We only ensure the SSE/streaming payload shape is preserved (answer + citations + usage), with a flag to enable RAG.

## Observability & quality

- Logging: request ids across Chatwoot ↔ rag-service; include account_id, assistant_id.
- Metrics: p95 latency for generate, retrieval hit rate, context token count, tool failure rate.
- Traces: OpenTelemetry (propagate traceparent).
- Evaluation: add nightly regression prompts + LLM-as-judge scoring; save to a table (rag.evals).

## Security

- HMAC (RAG_AUTH_HMAC_KEY) between Chatwoot and rag-service; reject unsigned/expired requests.
- Restrict rag-service to the internal Docker network; no public ports.
- PII scrubbing in logs; configurable redaction rules.

## Rollout strategy

- Phase 0 (1–2 days): spike rag-service skeleton + Ruby client in a feature branch; no production traffic.
- Phase 1 (3–5 days): implement /v1/index and /v1/search; backfill a small document set; write E2E tests.
- Phase 2 (5–7 days): implement /v1/generate with streaming and citations; tool bridging for 2–3 core tools.
- Phase 3 (3–4 days): staging rollout behind FEATURE_RAG_ENABLED for a pilot account; add dashboards.
- Phase 4 (2–3 days): production canary; monitor; if stable, widen.
- Phase 5: deprecate Captain LLM pipeline codepaths; keep data for N days; then drop.

## Risk & mitigations

- Retrieval quality regressions → keep Captain fallback; add RAG reranker flag.
- Token/latency cost spikes → context window budgeting and selective chunk retrieval; cache.
- Tool invocation failures → circuit breaker + queued retries; idempotency keys.
- Vector DB growth → TTL for stale chunks; compaction and deduplication.

## Detailed task list

1. Create rag-service (Python, FastAPI)
   - App skeleton, settings, HMAC middleware
   - /v1/index (chunking, embeddings, upsert)
   - /v1/search (cosine similarity; optional rerank)
   - /v1/generate (prompt templating + retrieved context, streaming)
2. Vector store and schema
   - Create rag.* tables in Postgres (pgvector)
   - Migrations managed by Alembic (service-local)
3. Ruby adapter and feature flag
   - Rag::Client with HMAC
   - Flag gate in Captain LLM integration points
4. Tools bridge
   - Define /internal/tools/execute in Chatwoot (authz per account)
   - Tool registry endpoint + LangChain dynamic tool set
5. Ingestion path parity
   - Map Captain document create/show/index to rag index calls
   - Background job for re-embedding existing docs
6. Streaming & UI compatibility
   - Maintain payload shape, SSE; add tests
7. QA & Observability
   - Automated tests (unit/integration/E2E)
   - Dashboards for latency, hit rate, errors
8. Rollout
   - Staging pilot → prod canary → ramp
   - Fallback switch and rollback checklist

## Example stubs (illustrative only)

Ruby adapter (server → rag-service)
```ruby path=null start=null
module Rag
  class Client
    def initialize(base_url:, hmac_key:, timeout: 15)
      @conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.options.timeout = timeout
      end
      @hmac_key = hmac_key
    end

    def generate(payload, stream: false)
      headers = signed_headers(payload)
      path = stream ? "/v1/generate?stream=1" : "/v1/generate"
      @conn.post(path, payload, headers)
    end

    def index(payload)
      @conn.post("/v1/index", payload, signed_headers(payload))
    end

    def search(payload)
      @conn.post("/v1/search", payload, signed_headers(payload))
    end

    private

    def signed_headers(body)
      ts = Time.now.to_i.to_s
      mac = OpenSSL::HMAC.hexdigest("SHA256", @hmac_key, ts + body.to_json)
      { "X-RAG-Timestamp" => ts, "X-RAG-Signature" => mac }
    end
  end
end
```

Python FastAPI (rag-service skeleton)
```python path=null start=null
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel

app = FastAPI()

class GenerateRequest(BaseModel):
    messages: list
    retrieval: dict | None = None
    assistant_config: dict | None = None
    streaming: bool = False

@app.post("/v1/generate")
async def generate(req: GenerateRequest, request: Request):
    # TODO: verify HMAC, retrieve top_k chunks, build prompt, stream tokens
    return {
        "answer": "stub",
        "citations": [],
        "usage": {"input_tokens": 0, "output_tokens": 0}
    }
```

Chunking defaults
```yaml path=null start=null
chunking:
  splitter: recursive_character
  size: 1200  # characters (≈ 400–600 tokens)
  overlap: 150
embeddings:
  model: text-embedding-3-large
  normalize: true
retrieval:
  top_k: 6
  rerank: false
```

## Data migration strategy

- Create rag.* tables without altering Captain tables.
- Backfill: for each Captain::Document, fetch content, chunk + embed to rag.*; record mapping (captain_document_id → rag.document.external_id).
- Switch reads to rag-service behind the feature flag. Writes (new docs) go to rag-service when flag is on.
- After N days stable, mark Captain embeddings pipeline as deprecated; plan drop in a later migration.

## SSH alias (xDEP) — optional developer convenience

To simplify remote ops (no action taken by this plan):
```sshconfig path=null start=null
Host xDEP
  HostName 3.80.120.208
  User ubuntu
  IdentityFile ~/.ssh/daon.pem
  IdentitiesOnly yes
```
Use with: `ssh xDEP`.

## Acceptance criteria

- Feature flag toggles between Captain and Rag with no UI regressions.
- RAG responses include citations with accurate sources (>80% of evaluation set).
- p95 end-to-end generate latency ≤ Captain p95 ±10% at launch.
- Zero data loss for existing documents; backfill completeness ≥ 99%.
- Clear rollback path: single env switch re-enables Captain.

## Open questions

- Which embedding provider do we standardize on for production? (OpenAI vs. vendor‑neutral)
- Do we enforce per‑account vector namespaces or shared with row‑level ACLs?
- Which reranker (if any) do we ship in v1?
- Tooling for complex multi‑step workflows (LangGraph) — v1 or v1.1?

## Capability matrix (Captain/Copilot → RAG)

- Assistant chat (copilot replies)
  - Current: Captain::LLM pipeline builds prompts and calls provider; returns tokens via SSE.
  - RAG: rag-service /v1/generate builds prompt + retrieves context (pgvector) and streams tokens; Rails adapter streams to UI.
  - Status: Replace in Phase 2; fallback to Captain via feature flag.

- Conversation suggestions in UI (message composer helpers)
  - Current: UI hits existing Rails endpoints backed by Captain.
  - RAG: Same endpoints; Rails delegates to rag-service /v1/generate with conversation context.
  - Status: No UI changes; backend swap behind flag.

- Document upload/ingestion/indexing
  - Current: Captain document models + jobs create embeddings and store metadata.
  - RAG: Rails calls rag-service /v1/index; chunks + embeds stored in pgvector (rag.*).
  - Status: Phase 1; backfill job migrates existing docs incrementally.

- Web crawl ingestion (Firecrawl parity)
  - Current: Captain jobs (firecrawl_service, parsers) fetch and index.
  - RAG: Keep existing fetchers initially; send content to /v1/index. Optional: move crawler into rag-service later.
  - Status: Phase 1 (adapter) → Phase 2.5 (native connector optional).

- Search (documents/articles/conversations)
  - Current: Captain services (search_*_service.rb) over Captain indices.
  - RAG: rag-service /v1/search with filters; Rails adapter normalizes results.
  - Status: Phase 1; keep API responses stable.

- FAQ generation (including paginated variants)
  - Current: Captain::LLM::faq_* services.
  - RAG: /v1/generate with templates and retrieval; optional rerank.
  - Status: Phase 2; parity tests before flip.

- Tools (add_private_note, add_label_to_conversation, update_priority, handoff, etc.)
  - Current: Invoked inside Captain pipeline as Ruby services.
  - RAG: Exposed to rag-service as signed webhooks (/internal/tools/execute); actual effects still in Rails.
  - Status: Phase 2; start with 2–3 core tools, expand.

- Streaming responses + citations
  - Current: SSE to UI; Captain assembles citations.
  - RAG: rag-service streams tokens and returns citations (chunk metadata); Rails proxies stream unchanged.
  - Status: Phase 2; ensure payload shape compatibility.

- Guardrails/guidelines and system prompts
  - Current: Stored in Captain config, merged into prompts.
  - RAG: Passed via assistant_config to /v1/generate; prompt templating handled in rag-service.
  - Status: Phase 2; parity required.

- Scenarios and assistant presets
  - Current: Captain::Scenario config influences prompts/tools.
  - RAG: Rails sends scenario data to rag-service; tool whitelist/parameters derived from registry.
  - Status: Phase 2+; retain data model; runtime swap only.

- Embeddings maintenance / re-embed jobs
  - Current: Captain jobs compute/store embeddings.
  - RAG: rag-service owns embeddings; Rails enqueues re-index; pgvector shared DB.
  - Status: Phase 1 (index) + Phase 2 (update jobs).

- Limits, billing, permissions
  - Current: Rails (Enterprise) enforces rate/usage, plan features, and ACLs.
  - RAG: Rails continues to enforce; rag-service emits usage metrics for observability only.
  - Status: Not replaced.

- Analytics/metrics/telemetry
  - Current: Rails logs + any existing dashboards.
  - RAG: Add request/latency/hit-rate metrics from rag-service; correlate with Rails request ids.
  - Status: Phase 3.
