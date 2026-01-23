# HealthScanner Backend Architecture (Simplified)

## Phased Alignment

This document describes the full target shape of the simplified monolith. For an actually shippable path, align it with the phased roadmap:

- **Phase 0**: Stateless FastAPI only (no database).
- **Phase 1 (MVP)**: Add PostgreSQL, synchronous endpoints, no Redis/MinIO/workers.
- **Phase 2**: Add Redis queue + workers + object storage for async scans and image storage.
- **Phase 3**: Add catalog ETL, deltas, and contributions pipeline.

Reference: `MDs/ARCHITECTURE_PHASED_ROADMAP.md`.

## Philosophy Change

**Original approach**: 6+ microservices from day one
**Simplified approach**: 3-tier monolith with clear module boundaries, extract services only when scale demands

This document revises the original proposal to reduce operational complexity while preserving all core capabilities.

---

## Objectives (Unchanged)

- Move server-friendly nutrition analysis, data aggregation, and AI orchestration out of the iOS app
- Keep the client focused on capture, UX, and light data shaping while preserving mission-critical on-device intelligence
- Enable faster iteration on business logic, security, and integrations
- Provide a scalable foundation for future features (collaboration, analytics, recommendations)

---

## Guiding Principles (Revised)

- **Start simple, scale selectively**: Single deployable backend, extract services when bottlenecks emerge
- **Client-first with edge assist**: On-device intelligence handles high-confidence cases, backend enriches the rest
- **Async-first processing**: Heavy analysis work is queued to keep the UI responsive
- **Privacy by design**: Minimize PII storage, encrypt assets, enforce strict retention policies
- **Pragmatic observability**: Focus on errors and performance, avoid premature telemetry complexity

---

## Simplified Architecture

```
┌───────────────────────────────┐
│  iOS Client (Swift)           │
│  • Camera capture + CoreML    │
│  • On-device heuristics       │
│  • Offline nutrition cache    │
│  • Sync queue + UI            │
└────────────┬──────────────────┘
             │ HTTPS/JSON
             ▼
┌────────────────────────────────┐
│  Backend Monolith (FastAPI)   │
│                                │
│  ┌──────────────────────────┐ │
│  │  API Layer (BFF)         │ │
│  │  • Auth, rate limiting   │ │
│  │  • Request validation    │ │
│  └────────┬─────────────────┘ │
│           │                    │
│  ┌────────▼─────────────────┐ │
│  │  Business Logic Modules  │ │
│  │  • Scan orchestration    │ │
│  │  • Catalog lookups       │ │
│  │  • User preferences      │ │
│  │  • LLM integration       │ │
│  │  • Contribution pipeline │ │
│  └────────┬─────────────────┘ │
│           │                    │
│  ┌────────▼─────────────────┐ │
│  │  Data Access Layer       │ │
│  │  • PostgreSQL queries    │ │
│  │  • Redis caching         │ │
│  │  • Object storage        │ │
│  └──────────────────────────┘ │
└─────┬──────────────┬───────────┘
      │              │
┌─────▼────┐   ┌────▼──────┐   ┌──────────────┐
│PostgreSQL│   │Redis Queue│   │MinIO/S3      │
│(Primary) │   │(Jobs/Cache)   │(Images/Blobs)│
└──────────┘   └───────────┘   └──────────────┘

Background Workers (same codebase):
┌────────────────────────────────┐
│  Worker Processes (Celery/ARQ)│
│  • Scan enrichment            │
│  • Contribution processing    │
│  • Catalog sync jobs          │
└────────────────────────────────┘
```

---

## Component Responsibilities

### iOS Client (Unchanged)

- Capture images/video, run on-device CoreML model for immediate food detection and heuristics
- Maintain a lightweight local nutrition cache for common Swedish products seeded from `all_products_enriched_normalized.json`
- Queue outbound API requests when offline and replay once connectivity is restored
- Present scan progress, trigger backend jobs, poll for completion
- Securely store auth tokens (Sign in with Apple) and pass to backend
- Use SwiftData + CloudKit private databases for end-to-end-encrypted opt-in backups
- Offer guided "Add Product" flow with local-first, cloud-optional submission

### Backend Monolith (New Consolidated Approach)

**Single application with modular structure:**

#### API Layer (BFF Pattern)
- Terminates TLS, validates JWTs (Sign in with Apple tokens)
- Rate limiting: Redis-backed sliding window (e.g., 100 scans/day/user, 10 req/min)
- Request validation with Pydantic models
- Response shaping tailored for iOS (consistent schemas)
- Generates short-lived signed URLs for direct-to-MinIO uploads

**Endpoints:**
- `POST /v1/scans/plate` → enqueues scan job, returns `jobId`
- `GET /v1/scans/{jobId}` → poll for job status + results
- `POST /v1/scans/barcode` → barcode lookup with catalog fallback
- `POST /v1/catalog/contributions` → submit new product
- `GET /v1/catalog/contributions/{id}` → moderation status
- `GET /v1/users/me/history?limit=20` → paginated meal history
- `PUT /v1/users/me/preferences` → update dietary settings
- `GET /v1/catalog/delta?since=<version>` → incremental catalog sync
- `GET /v1/health` → healthcheck (database + Redis connectivity)

#### Business Logic Modules

**Scan Orchestration Module:**
- Receives device-submitted detections + heuristic context
- Checks confidence scores; skip enrichment if >0.8 threshold
- Enqueues low-confidence scans to worker queue (Redis + PostgreSQL-backed with ARQ)
- Tracks job state: `Queued → Processing → Completed/Failed`
- Returns unified `NutritionBreakdown` schema to client

**Catalog Module:**
- Ingests `all_products_enriched_normalized.json` on scheduled import job
- Stores products in PostgreSQL with EAN, brand, category indexes
- Fast lookups: EAN → product with nutrition facts + thumbnail URLs
- Falls back to OpenFoodFacts API when local catalog misses
- Caches hot entries (top 10k products) in Redis for <50ms response times
- Generates delta manifests (versioned) for client cache updates

**LLM Integration Module:**
- Stores prompt templates in database (versioned for A/B testing)
- Handles OpenAI API calls with retry logic and timeout (10s max)
- Validates responses against JSON schema (Pydantic models)
- Masks API keys (environment variables, never exposed to client)
- Logs prompts/responses with PII redaction for debugging
- Implements per-user budget tracking (PostgreSQL counters)

**User & Preferences Module:**
- Maintains pseudonymous user profiles (auth_provider_id → internal user_id)
- Stores opt-in preferences: allergens, dietary goals (encrypted at rest)
- Minimal telemetry: aggregated scan counts, popular products (no meal histories)
- Feature flags with sensible defaults (no external service, just database table)

**Contribution Processing Module:**
- Accepts user-submitted product assets (barcode photo, nutrition label, manual data)
- Enqueues to worker for OCR extraction (Tesseract or cloud OCR API)
- Validates EAN checksums, nutrition fact ranges, allergen keywords
- Routes low-confidence entries to manual moderation queue (admin UI, future)
- Merges approved items into catalog staging → production → OpenFoodFacts export

#### Data Access Layer

**PostgreSQL (Primary Store):**
- Users, scans, scan_results, products, user_preferences, audit_events
- Full-text search on products (GIN indexes for Swedish text)
- Transaction support for multi-table operations
- Connection pooling (pgBouncer or native pooling)

**Redis (Cache + Queue):**
- Session state and rate limit counters (TTL-based)
- Job queue for background workers (Redis Streams or simple lists)
- Hot catalog entries (LRU cache, 10k products)
- Pub/Sub for optional real-time scan completion events

**MinIO/S3 (Object Storage):**
- Raw scan images (encrypted at rest, 30-day retention)
- Product contribution photos (staged → archived post-moderation)
- Catalog thumbnails (CDN-cacheable, public URLs for approved products)
- Versioned catalog exports for client sync

---

## Background Workers

**Same codebase, separate processes:**

Uses **ARQ** (async Redis queue for Python) or **Celery** (if more mature ecosystem needed).

**Worker tasks:**
1. **Scan Enrichment Job** (`process_scan_job`):
   - Fetches device detections from PostgreSQL
   - Queries catalog for recognized items
   - Calls LLM API for low-confidence cases
   - Updates scan status and stores results
   - Publishes completion event to Redis pub/sub

2. **Contribution Processing Job** (`process_contribution`):
   - Downloads user-submitted images from MinIO
   - Runs OCR on nutrition label (Tesseract or Cloud Vision API)
   - Validates extracted fields (confidence scoring)
   - Stages product record with provenance metadata
   - Notifies user of acceptance/rejection

3. **Catalog Sync Job** (`sync_catalog`):
   - Runs daily/weekly: fetches `all_products_enriched_normalized.json`
   - Loads into staging tables, validates schema
   - Deduplicates, normalizes thumbnails
   - Generates delta manifest (new/updated/deleted products)
   - Promotes to production catalog

**Scaling:** Workers can be horizontally scaled (Docker Compose `replicas: 3`) based on Redis queue length.

---

## Simplified Observability

**Eliminate:** OpenTelemetry, Grafana, Loki, Promtail (too complex for early stage)

**Replace with:**

### 1. Error Tracking: **Sentry**
- Automatic exception capture with stack traces
- Breadcrumbs for debugging (request details, user context)
- Performance monitoring for slow endpoints (>1s response time alerts)
- Budget-friendly ($26/month for small team)

### 2. Application Logs: **Structured stdout + Docker logs**
- JSON-formatted logs (timestamp, level, message, context)
- Docker Compose captures to local files
- Production: CloudWatch Logs / Google Cloud Logging (searchable)
- Keep logs for 30 days, archive critical events to S3

**Log structure:**
```json
{
  "timestamp": "2025-11-02T14:32:10Z",
  "level": "info",
  "service": "api",
  "endpoint": "/v1/scans/plate",
  "user_id": "anon_12345",
  "job_id": "scan_abc123",
  "duration_ms": 145,
  "message": "Scan job enqueued successfully"
}
```

### 3. Metrics: **Simple Prometheus + Grafana (optional)**
- If needed, add Prometheus for basic metrics (request count, latency, queue depth)
- Grafana for dashboards (deferred to production launch)
- Start with health checks + Sentry performance monitoring instead

### 4. Healthchecks
- `/v1/health` endpoint: PostgreSQL connectivity, Redis ping, MinIO bucket access
- External uptime monitoring (UptimeRobot, Better Uptime) pings every 5 minutes
- Alerts via email/Slack when down

---

## Deployment Topology

### Local Development: **Docker Compose**

```yaml
services:
  api:
    build: .
    ports: ["8000:8000"]
    depends_on: [postgres, redis, minio]
    env_file: .env.local

  worker:
    build: .
    command: arq worker
    depends_on: [postgres, redis, minio]
    env_file: .env.local

  postgres:
    image: postgres:16
    volumes: [./data/postgres:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: healthscanner
      POSTGRES_PASSWORD: local_dev_password

  redis:
    image: redis:7-alpine
    volumes: [./data/redis:/data]

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports: ["9000:9000", "9001:9001"]
    volumes: [./data/minio:/data]
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
```

**One command to start:** `docker compose up`

### Production: **Managed Services**

- **API + Workers**: Render.com, Railway, Fly.io (Docker-based deploys)
- **PostgreSQL**: Managed instance (RDS, Supabase, Neon)
- **Redis**: Upstash, Redis Cloud (serverless tiers available)
- **Object Storage**: AWS S3, Cloudflare R2, Backblaze B2
- **Secrets**: Environment variables injected by platform (no Vault complexity)

**Scaling approach:**
- Start with single API instance + 2 workers
- Scale horizontally when response time >500ms P95
- PostgreSQL vertical scaling before read replicas
- Redis cluster only if cache exceeds 4GB

---

## Data Model (Simplified)

### Core Tables

```sql
-- Users (minimal PII)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_provider_id TEXT UNIQUE NOT NULL,  -- Sign in with Apple ID
  locale TEXT DEFAULT 'sv_SE',
  created_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ
);

-- Scans
CREATE TABLE scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  type TEXT CHECK (type IN ('plate', 'barcode', 'label')),
  status TEXT CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
  confidence_score DECIMAL(3,2),  -- 0.00 to 1.00
  source_image_url TEXT,  -- MinIO URL
  device_payload JSONB,  -- CoreML detections + heuristics
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  INDEX idx_user_scans (user_id, created_at DESC)
);

-- Scan Results
CREATE TABLE scan_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID REFERENCES scans(id) ON DELETE CASCADE,
  nutrition_breakdown JSONB NOT NULL,  -- Unified schema
  detected_items JSONB,  -- Array of {name, portion, confidence}
  llm_prompt_version TEXT,  -- For A/B testing
  llm_model TEXT,  -- e.g., "gpt-4o-mini"
  source_type TEXT CHECK (source_type IN ('device_only', 'catalog', 'llm_enriched')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Products (Swedish catalog)
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ean TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  nutrition_facts JSONB NOT NULL,  -- Per 100g standardized
  ingredients TEXT[],
  allergens TEXT[],
  thumbnail_url TEXT,  -- MinIO/S3 URL
  source TEXT CHECK (source IN ('swedish_catalog', 'openfoodfacts', 'user_contributed')),
  confidence_score DECIMAL(3,2),
  last_synced_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  INDEX idx_ean (ean),
  INDEX idx_search (name gin_trgm_ops)  -- Full-text search
);

-- User Preferences (opt-in only)
CREATE TABLE user_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  allergens TEXT[],
  dietary_goals JSONB,  -- {calorie_target: 2000, protein_min: 50}
  sync_enabled BOOLEAN DEFAULT false,  -- CloudKit sync opt-in
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Contribution Submissions
CREATE TABLE product_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  ean TEXT NOT NULL,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')),
  barcode_image_url TEXT,
  label_image_url TEXT,
  extracted_nutrition JSONB,  -- OCR results
  manual_overrides JSONB,  -- User-provided corrections
  moderation_notes TEXT,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);

-- Audit Events (security tracking)
CREATE TABLE audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,  -- e.g., 'scan_created', 'preference_updated'
  resource_type TEXT,
  resource_id UUID,
  metadata JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT now(),
  INDEX idx_audit_user (user_id, created_at DESC)
);
```

---

## Security & Privacy

### Authentication
- **Sign in with Apple** (recommended): ID tokens validated on backend
- JWTs stored in iOS Keychain, passed in `Authorization: Bearer` header
- Token refresh flow with 30-day expiration

### Rate Limiting
```python
# Redis-backed sliding window
@rate_limit(limit=100, window=86400, scope="user")  # 100 scans/day
@rate_limit(limit=10, window=60, scope="user")     # 10 req/min
async def create_scan(user_id: str, payload: ScanRequest):
    ...
```

### Data Encryption
- **At rest**: PostgreSQL transparent data encryption (TDE) in production
- **In transit**: TLS 1.3 for all API calls, MinIO HTTPS
- **Client-side**: SwiftData encryption + CloudKit E2EE for opted-in backups

### Data Retention
- Raw scan images: **30 days** → auto-delete via MinIO lifecycle policy
- Scan metadata: **1 year** → archived to cold storage
- User account deletion: **7-day grace period** → hard delete all records

### Secrets Management
- Development: `.env.local` (gitignored, 1Password for team sharing)
- Production: Platform environment variables (Render/Railway secrets)
- API keys rotated quarterly, logged in audit table

---

## Migration Strategy (Revised)

### Phase 1: Foundation (Weeks 1-2)
**Goal:** Standalone backend running locally, no app integration yet

- Set up Docker Compose stack (API, worker, PostgreSQL, Redis, MinIO)
- Implement auth endpoint (`POST /v1/auth/apple`) with JWT generation
- Create database schema and seed Swedish catalog (`products` table)
- Build barcode lookup endpoint (`POST /v1/scans/barcode`)
- Add healthcheck endpoint and Sentry error tracking
- Write API contract tests (Postman/Pytest)

**Deliverable:** Backend responds to barcode queries with nutrition data

---

### Phase 2: Scan Processing (Weeks 3-4)
**Goal:** Plate scan jobs working end-to-end

- Implement scan job queue (ARQ workers)
- Build plate scan endpoint (`POST /v1/scans/plate`) with job polling
- Integrate LLM module (OpenAI API fallback for low-confidence scans)
- Add catalog fallback to OpenFoodFacts for missing products
- Test worker scaling (3 replicas, 100 concurrent scans)

**Deliverable:** Backend enriches device detections and returns nutrition summaries

---

### Phase 3: iOS Integration (Weeks 5-6)
**Goal:** App successfully calls backend, with feature flag toggle

- Define shared Swift DTOs matching backend schemas
- Add backend API client to iOS app (URLSession wrapper)
- Implement offline queue with retry logic (SwiftData table)
- Feature flag: "Use Backend for Scans" (default OFF)
- A/B test with 10% of users (TestFlight beta)

**Deliverable:** App can optionally use backend instead of direct OpenAI calls

---

### Phase 4: User Contributions (Weeks 7-8)
**Goal:** Users can submit missing products to shared catalog

- Build contribution submission endpoint (`POST /v1/catalog/contributions`)
- Implement OCR worker (Tesseract for nutrition label extraction)
- Add validation pipeline (EAN checksum, field ranges)
- Create moderation queue (admin API for approval/rejection)
- Test approved contribution → catalog delta → client sync

**Deliverable:** User-submitted products flow into catalog updates

---

### Phase 5: Production Launch (Weeks 9-10)
**Goal:** Backend handles 100% of scans, decommission legacy paths

- Remove OpenAI API key from iOS app bundle
- Flip feature flag to 100% backend usage
- Deploy to production hosting (Render/Railway)
- Set up uptime monitoring and alerting
- Monitor Sentry for errors, scale workers as needed

**Deliverable:** Backend is primary nutrition processing engine

---

## Technology Stack

### Backend: **FastAPI (Python 3.12+)**
**Why:**
- Fast development iteration (async/await native)
- Excellent API documentation (auto-generated OpenAPI)
- Strong typing with Pydantic (validation + serialization)
- Large ecosystem (SQLAlchemy, ARQ, Sentry integration)

**Alternatives considered:**
- NestJS (TypeScript): More verbose, smaller ecosystem
- Django: Heavier, sync-first architecture

### Workers: **ARQ (Async Redis Queue)**
**Why:**
- Lightweight, Redis-based (no extra services)
- Python async/await compatible
- Simple retry/scheduling logic
- Easy to understand codebase

**Alternative:** Celery (more mature but complex for our needs)

### Database: **PostgreSQL 16**
**Why:**
- Full-text search (GIN indexes for Swedish product names)
- JSON support (flexible nutrition schemas)
- Strong consistency guarantees
- Proven scalability (millions of products)

### Cache/Queue: **Redis 7**
**Why:**
- Job queue + cache in single service
- Pub/Sub for real-time events (optional)
- Widely supported, easy to deploy

### Object Storage: **MinIO (local) / S3 (production)**
**Why:**
- S3-compatible API (easy migration)
- MinIO perfect for Docker Compose dev setup
- Low cost for production (R2, Backblaze B2)

---

## Cost Estimates (Monthly, Production)

| Service | Provider | Usage | Cost |
|---------|----------|-------|------|
| **Backend Hosting** | Render.com | 1 instance (1GB RAM) | $7 |
| **Worker Hosting** | Render.com | 2 instances (512MB each) | $10 |
| **PostgreSQL** | Supabase | 500MB DB | Free tier |
| **Redis** | Upstash | 1GB cache | Free tier |
| **Object Storage** | Cloudflare R2 | 10GB images | $0.15 |
| **OpenAI API** | OpenAI | 1000 scans/month @ $0.02/scan | $20 |
| **Sentry** | Sentry | Error tracking | $26 |
| **Domain + SSL** | Cloudflare | DNS + certs | Free |
| **Total** | | | **~$63/month** |

**At scale (10k scans/month):**
- OpenAI API: ~$200/month (largest variable cost)
- Hosting: Scale to $50-100/month (2-4 instances)
- **Total: ~$300/month**

**Mitigation:** Device-first intelligence keeps 70-80% of scans local, reducing API costs significantly.

---

## API Versioning & Deprecation

### Versioning Strategy
- URL-based versioning: `/v1/scans/plate`
- Maintain backward compatibility for 6 months minimum
- Announce breaking changes 3 months in advance (in-app notifications)

### Deprecation Process
1. Add `X-API-Deprecation` header to old endpoints
2. Log usage metrics for deprecated endpoints
3. Release new `/v2/` endpoints alongside old ones
4. Force upgrade when <5% of requests use old version
5. Remove old endpoints after 6-month sunset period

### Contract Testing
- OpenAPI spec generated from Pydantic models
- Swift DTOs auto-generated from OpenAPI (via `openapi-generator`)
- CI/CD runs contract tests on every PR (Dredd or Pact)

---

## Success Metrics

### Performance KPIs
- **API Response Time**: P50 <200ms, P95 <500ms, P99 <1s
- **Worker Job Latency**: P95 <5s for scan enrichment
- **Catalog Lookup**: <50ms for cached products, <200ms for database queries
- **Uptime**: 99.5% (3.6 hours downtime/month acceptable at this stage)

### Business Metrics
- **Device-First Success Rate**: >75% of scans handled without backend LLM calls
- **Catalog Hit Rate**: >60% of barcode scans found in Swedish catalog
- **User Contribution Rate**: >5% of users submit at least one product
- **OpenFoodFacts Exports**: 100+ new Swedish products/month from contributions

### Cost Efficiency
- **Cost per Scan**: <$0.05 (including API, hosting, storage)
- **OpenAI API Budget**: <$500/month for 10k scans

---

## Open Questions & Decisions Needed

### 1. Technology Choice
- **FastAPI (Python)** vs **NestJS (TypeScript)**?
- Recommendation: FastAPI (faster iteration, better ML ecosystem)

### 2. Worker Queue
- **ARQ (lightweight)** vs **Celery (mature)**?
- Recommendation: ARQ (simpler for Docker Compose, easier to debug)

### 3. OCR Provider
- **Tesseract (free, self-hosted)** vs **Google Cloud Vision (paid, better accuracy)**?
- Recommendation: Start with Tesseract, upgrade to Cloud Vision if accuracy <80%

### 4. Real-Time Updates
- **WebSocket** vs **Server-Sent Events (SSE)** vs **Polling**?
- Recommendation: Polling for MVP (simple), SSE for production (easier than WebSocket)

### 5. Admin UI for Moderation
- Build custom dashboard or use off-the-shelf (Retool, AdminJS)?
- Recommendation: Defer to Phase 4, use database client initially

---

## Next Steps (Immediate Actions)

### Week 1: Planning & Setup
- [ ] Finalize technology stack (FastAPI + ARQ decision)
- [ ] Create backend repository with Docker Compose scaffold
- [ ] Define OpenAPI schema (shared contracts with iOS team)
- [ ] Set up CI/CD (GitHub Actions: lint, test, build Docker image)

### Week 2: Core Implementation
- [ ] Implement authentication (Sign in with Apple token validation)
- [ ] Build barcode lookup endpoint with Swedish catalog integration
- [ ] Set up Sentry error tracking
- [ ] Write first integration tests (Pytest + httpx)

### Week 3: Worker Infrastructure
- [ ] Configure ARQ workers with Redis Streams
- [ ] Implement scan job processing pipeline
- [ ] Add LLM integration module with OpenAI API
- [ ] Test worker scaling (Docker Compose replicas)

### Week 4: iOS Integration Planning
- [ ] Generate Swift DTOs from OpenAPI spec
- [ ] Design offline queue architecture (SwiftData)
- [ ] Plan feature flag implementation (Firebase Remote Config or custom)
- [ ] Schedule sync meeting with iOS team for API contract review

---

## Conclusion

This simplified architecture achieves all original goals while dramatically reducing operational complexity:

**Eliminated:**
- 4 separate services → 1 monolith with modules
- OpenTelemetry/Grafana/Loki stack → Sentry + structured logs
- Complex service mesh → Simple HTTP + worker queue
- Kubernetes overhead → Docker Compose (dev) + managed hosting (prod)

**Preserved:**
- Privacy-first design (opt-in sync, E2EE, minimal PII)
- Device-first intelligence (CoreML + heuristics)
- Async processing (worker queue for heavy tasks)
- Scalability path (clear extraction points when needed)
- Full feature set (scans, catalog, contributions, preferences)

**Result:** Faster development, easier debugging, lower operational burden, same capabilities.

The team can ship an MVP backend in 4-6 weeks and iterate based on real usage patterns rather than premature optimization.
