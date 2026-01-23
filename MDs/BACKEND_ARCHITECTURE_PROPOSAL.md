# HealthScanner Backend Architecture Proposal

## Objectives
- Move server-friendly nutrition analysis, data aggregation, and AI orchestration out of the iOS app.
- Keep the client focused on capture, UX, and light data shaping while preserving mission-critical on-device intelligence.
- Enable faster iteration on business logic, security, and integrations.
- Provide a scalable foundation for future features (collaboration, analytics, recommendations).

## Guiding Principles
- **Client-thin, service-rich (with edge assist)**: UI collects inputs while retaining on-device intelligence for latency-sensitive tasks.
- **Composable services**: Discrete services for ingestion, analysis, open-data, and persistence.
- **Async-first processing**: Heavy analysis work is queued to keep the UI responsive.
- **Observability & governance**: Every external call is monitored, rate-limited, and auditable.
- **Privacy by design**: Minimize PII storage, encrypt assets, and enforce strict retention policies.

## Target-State Overview
```
┌───────────────────────────────┐
│  iOS Client (Swift)           │
│  • Camera capture + CoreML    │
│  • On-device heuristics       │
│  • Offline nutrition cache    │
│  • Sync queue + UI            │
└────────────┬──────────────────┘
             │ HTTPS/JSON (sync, fallbacks)
             ▼
┌──────────────────────────────┐
│  API Gateway / BFF (REST)    │
│  • AuthN/AuthZ, rate limits  │
│  • Response shaping for iOS  │
└──────┬───────────────────────┘
       │
┌──────▼──────┐        ┌──────────────┐        ┌─────────────────────┐        ┌────────────────────────┐
│ Scan        │        │ User + Config│        │ Open Data Aggregator │        │ LLM Integration Service │
│ Processing  │        │ Service      │        │ (Swedish catalog +   │        │ (fallback summarization)│
│ Service     │        │ • Profiles   │        │  OpenFoodFacts)      │        └──────────┬────────────┘
│ • Queue +   │        │ • Preferences│        └──────────┬───────────┘                   │
│   Worker    │        └──────┬───────┘                   │                              │
       │                      │                           │                              │
       └───────────────┬──────┴──────────────┬────────────┘                              │
                       │                     │                                           │
                ┌──────▼────────┐     ┌──────▼────────┐                            ┌─────▼────────┐
                │ Object Storage │     │ Analytics/Logs│                            │ Secrets/Keys │
                │ (backups, imgs)│     │ Monitoring    │                            └──────────────┘
                └───────────────┘     └───────────────┘
```

## Component Responsibilities

### iOS Client
- Capture images/video, run on-device CoreML model for immediate food detection and heuristics.
- Maintain a lightweight local nutrition cache for common Swedish products seeded from `all_products_enriched_normalized.json`; merge with backend responses when available.
- Queue outbound API requests (plate scans, barcode lookups, preference updates) when offline and replay once connectivity is restored.
- Present scan progress, trigger backend jobs, poll or subscribe for completion.
- Cache recent results for offline viewing; sync with backend when connectivity returns (conflict resolution handled client ↔ backend).
- Securely store auth tokens (Sign in with Apple recommended) and pass to backend.
- Persist user preferences, allergens, and meal history locally first; expose opt-in toggles for what, if anything, syncs to the cloud.
- Use SwiftData for structured persistence and CloudKit private databases for seamless, end-to-end-encrypted backup/migration of opt-in records; keep sensitive assets (e.g., raw images) local unless explicitly shared.
- Offer a guided “Add Product” flow when catalog lookups miss—capture barcode, package, nutrition label photos, and manual fields; respect user choice to keep submissions local or share with the shared catalog/open data.

### API Gateway / Backend-for-Frontend
- Terminates TLS, validates JWTs, handles rate limiting and request shaping.
- Provides thin REST surface tailored for the app (e.g., `POST /scans/plate`, `POST /scans/barcode`, `GET /me/history`).
- Publishes short-lived signed upload URLs if direct-to-storage uploads are required.

### Scan Processing Service
- Stateless REST API that enqueues incoming scans (Redis, RabbitMQ, or lightweight in-memory queue persisted to disk) and hands them to worker containers.
- Persists job state (`Queued → Processing → Completed/Failed`) in PostgreSQL so the client can poll or subscribe for updates.
- Workers consume device-submitted detections/heuristic context (and contribution payloads), enrich with catalog data, and only escalate to cloud AI if on-device confidence is insufficient.
- Normalizes combined results into a consistent nutrition payload for the client, runs the contribution validation pipeline, and emits completion events.

### On-Device Intelligence
- CoreML pipelines provide real-time object recognition, portion estimates, and text extraction without a network round trip.
- Heuristic scoring and rule-based tagging (built into the app) assemble a preliminary nutrition context for immediate feedback.
- Confidence scores and intermediate artifacts are shared with the backend when remote enrichment or LLM summarization is required, preserving device-first autonomy for high-confidence cases.

### LLM Integration Service
- Owns prompt templates, tool-call instructions, and safety rails for remote summarization when device heuristics are insufficient.
- Handles response validation, JSON schema enforcement, and retries.
- Masks API keys away from the client; logs prompts/responses with redaction for debugging.

### Product Contribution Processing
- Reuses the scan queue/worker infrastructure to ingest user-submitted product assets (barcode photo, package photo, nutrition label, manual overrides).
- Runs OCR and text-cleanup pipelines (on-device first, backend fallback) to extract nutrition facts and ingredients, scoring confidence for each field.
- Applies validation (EAN checksum, allergen keyword detection, duplicate detection) and routes low-confidence entries to manual moderation.
- Generates structured product records with provenance metadata, stores them in staging tables, and publishes approved items to the shared catalog and OpenFoodFacts.
- Sends completion/feedback events so users know when their contribution is accepted or requires more information.

### Open Data Aggregation Service
- Ingests the curated Swedish catalog (`all_products_enriched_normalized.json`) as the authoritative source for barcoded items, including thumbnails and enriched metadata.
- Exposes fast lookups (EAN → product) to both the backend orchestrator and the client sync API; supports incremental updates when the file is refreshed.
- Falls back to third-party providers (OpenFoodFacts, USDA, etc.) only when the local catalog misses, then stores successful fetches back into the catalog.
- Maintains a normalized ingredient + nutrition store in PostgreSQL plus image thumbnails in object storage.
- Implements cache warming, delta sync jobs, and scoring/conflict resolution logic across sources.
- Accepts vetted user contributions (images + metadata) from the Scan Processing Service, stages them for moderation, and merges approved items into the master catalog and open-data exports.

### User & Configuration Service
- Maintains pseudonymous user handles and minimal metadata required for server interactions (e.g., push tokens, subscription tier).
- Stores dietary preferences and allergens only when users explicitly opt in to sync; data is encrypted at rest and stripped of identifiers.
- Receives aggregated/anonymous usage telemetry (e.g., popular scans) for model learning; no raw meal histories or PII leave the device by default.
- Provides feature flag/config endpoints with privacy-preserving defaults (e.g., bucketing via differential privacy or anonymous tokens).

### Notification & Event Service
- Emits domain events (`ScanCompleted`, `ScanFailed`) onto a lightweight message channel (e.g., Redis Streams, NATS) suited for Docker Compose deployments.
- Drives push notifications or webhooks for partner integrations.
- Feeds analytics pipelines without blocking user flows.
- Broadcasts contribution lifecycle events (`ContributionReceived`, `ContributionApproved`) so the app can update users in real time.

### Shared Infrastructure
- **Relational DB**: PostgreSQL for users, scans, nutrition facts, prompt versions.
- **Queue/Cache**: Redis for session state, job queueing, rate limiting, and hot catalog entries (fits Docker Compose setup).
- **Object Storage**: S3-compatible storage (e.g., MinIO in compose, S3 in prod) for raw images, processed overlays, signed URLs for access.
- **Secrets**: Dotenv/1Password during development; Vault or SOPS-based configs in production.
- **Observability**: OpenTelemetry traces, structured logs, metrics dashboards, alerting hooks (Grafana/Loki/Promtail stack works well in containers).

## Deployment Topology
- **Local/Dev**: Docker Compose orchestration with services for API Gateway/BFF, Scan Processing API, worker containers, Redis, PostgreSQL, MinIO, and observability stack.
- **Staging/Prod**: Same container images deployed on managed Kubernetes, ECS, or Nomad; still minimal external dependencies.
- Health checks and rolling updates coordinated through container platform; workers scale horizontally based on queue length.

## Data Ingestion Pipeline
- Scheduled job ingests `~/Documents/workspace/json_products/all_products_enriched_normalized.json` (or its automated export) and publishes a versioned snapshot to object storage.
- ETL service loads the snapshot into staging tables, validates schema, deduplicates EANs, and normalizes thumbnails.
- Approved records flow into the production catalog tables powering the Open Data Aggregation Service.
- Differential manifests (new/updated/deleted items) are generated for efficient client cache updates.
- Catalog misses trigger OpenFoodFacts (or other provider) enrichment; accepted results are merged into the subsequent snapshot for curation.
- User contributions feed the same staging layer with provenance metadata (hashed user identifier, submission timestamp); automated checks and moderators decide whether to promote to production and export to open-data feeds.

## API Surface (Illustrative)
- `POST /v1/scans/plate` → uploads on-device detections/heuristic payload, starts enrichment job, returns `jobId`.
- `GET /v1/scans/{jobId}` → polling endpoint with job status + partial results.
- `POST /v1/scans/barcode` → accepts barcode, optional photo, returns nutrition lookup.
- `POST /v1/catalog/contributions` → submits new product data/photos; returns submission identifier and initial moderation status.
- `GET /v1/catalog/contributions/{id}` → provides moderation state, feedback, and eventual merged product reference.
- `GET /v1/users/me/history?limit=20` → paginated meal history.
- `PUT /v1/users/me/preferences` → updates dietary settings.
- `GET /v1/catalog/delta?since=<version>` → delivers incremental catalog updates for the on-device nutrition cache.
- WebSocket channel `/v1/realtime` or SSE stream for push completion events.

The backend should return consistent schemas (e.g., `NutritionBreakdown`, `Detection`, `SourceMetadata`) to allow the app to render results without business heuristics.

## Data Model Sketch (High Level)
- `users(id, auth_provider_id, name, locale, created_at, ...)`
- `scans(id, user_id, type, status, started_at, completed_at, source_image_url, ...)`
- `scan_results(id, scan_id, payload_json, confidence, prompt_version, openai_model, ...)`
- `ingredients(id, external_reference, name, nutrition_facts_json, last_synced_at, ...)`
- `user_preferences(user_id, allergens, goals_json, updated_at)`
- `audit_events(id, actor, action, metadata_json, created_at)`

## Operational & Security Considerations
- Enforce short-lived upload URLs, automatically purge raw imagery after configurable retention.
- Store prompts/responses in secure logging with PHI redaction.
- Rate limit per-user scan submissions to protect third-party APIs.
- Continuous health checks and circuit breakers for external dependencies (OpenAI, open data).
- Comprehensive test harness: contract tests (app ↔️ API), unit tests per service, synthetic canary scans.
- Disaster recovery: daily backups for PostgreSQL, versioned object storage, IaC-managed infrastructure.

### Offline & Edge Intelligence
- CoreML packaged within the app for immediate classification; periodically refreshed via app updates or modular downloads when online.
- Deterministic heuristics and small rules engines convert detections into provisional nutrition breakdowns; updates shipped with app releases.
- Encrypted local nutrition catalog (SQLite/SwiftData) seeded from backend sync jobs; initial payload derived from `all_products_enriched_normalized.json` (primary Swedish market) with later regional overlays.
- Reliable queue (e.g., background `SwiftData` table) that tracks pending network calls with exponential backoff once network resumes; CloudKit handles background push updates for opted-in records.
- Consistency strategies:
  - Last write wins for non-critical preferences.
  - Merge logic for scan history (client tags entries with temporary IDs, backend reconciles on ingest) when users opt into cloud backup.
  - Client annotates responses with provenance (local vs server) so UI can indicate confidence to users and whether data remained local.

## Migration Strategy
1. **Foundations**
   - Introduce API Gateway, auth, and skeleton services running alongside existing app usage via feature flag.
   - Extract request/response models from the app into shared schemas (Swift + backend DTOs).
2. **Nutrition Lookup (Barcode)**
   - Move barcode-to-nutrition logic to backend first; app calls new endpoint.
   - Validate caching, open data sync, and fallback flows.
3. **Plate Analysis**
   - Ship refined on-device CoreML bundle with heuristic summarization; upload detections/heuristic context when backend enrichment is required.
   - Maintain server-side LLM fallback routed through the Scan Processing Service queue for low-confidence cases while phasing out direct OpenAI calls from the app.
4. **History & Preferences**
   - Shift local persistence to backend; add sync layer for offline reads.
   - Expose new endpoints; app migrates to fetch/store via backend with conflict resolution.
5. **User Contributions**
   - Introduce the in-app contribution experience with local drafts and optional cloud submission.
   - Stand up contribution ingestion endpoints, worker pipeline (OCR + validation), and moderation tooling; iterate until acceptance flow is stable.
   - Promote approved contributions into catalog deltas and automate propagation to OpenFoodFacts.
6. **Decommission Legacy Paths**
   - Remove heavy business logic and API keys from the app bundle.
   - Optimize backend autoscaling and add advanced monitoring/alerting.

## Next Steps
- Validate technology choices against team skillset (e.g., FastAPI + Celery vs. TypeScript + NestJS).
- Define protobuf/JSON schemas and begin shared contract testing.
- Stand up CI/CD pipelines (lint, tests, deploy) for the backend repo.
- Plan phased app releases aligned with the migration milestones above.

This architecture separates concerns cleanly, centralizes sensitive operations, and positions HealthScanner to scale features, teams, and integrations without overloading the iOS client.
