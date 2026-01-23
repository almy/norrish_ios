# HealthScanner - Phased Backend Architecture

This document rewrites the backend plan into three explicit phases. Each phase is shippable, with clear scope and increasing complexity.

---

## Phase 0: Stateless Proxy (No Database)

**Goal**: Ship the smallest possible backend. No persistence. The app remains source-of-truth.

**Architecture**
```
iOS (Swift) -> FastAPI
```

**Scope**
- FastAPI monolith, single process.
- No database, no Redis, no object storage.
- Synchronous endpoints only.
- External API calls inline with strict timeouts.
- All history/preferences stay on-device.

**Core Endpoints**
- `POST /v1/scans/plate` (sync): accept device detections, return analysis.
- `POST /v1/scans/barcode` (sync): lookup by barcode, return product data.
- `GET /v1/health`: liveness check.

**Operational Simplicity**
- One container (API).
- No persistent storage.
- Basic logs to stdout.

**Exit Criteria**
- App can complete a scan end-to-end with a backend response.
- Latency under acceptable thresholds for synchronous calls.

---

## Phase 1: MVP Backend (FastAPI + Postgres)

**Goal**: Add persistence for scans/history/preferences. Still no queues, workers, or object storage.

**Architecture**
```
iOS (Swift) -> FastAPI -> PostgreSQL
```

**Scope**
- FastAPI monolith, single process.
- PostgreSQL for users, scans, results, and preferences.
- Synchronous endpoints only (no background jobs).
- Optional external API calls inline (e.g., OpenFoodFacts or LLM) with strict timeouts.

**Core Endpoints**
- `POST /v1/scans/plate` (sync): accept device detections, return result or fallback.
- `POST /v1/scans/barcode` (sync): lookup by barcode, return nutrition data.
- `GET /v1/users/me/history`: recent scans.
- `PUT /v1/users/me/preferences`: dietary settings.
- `GET /v1/health`: DB connectivity check.

**Data Model (Minimal)**
- `users`
- `scans`
- `scan_results`
- `user_preferences`

**Operational Simplicity**
- One container (API).
- One database (Postgres).
- Basic logs to stdout.
- No Redis, no object storage, no workers.

**Exit Criteria**
- App can complete a scan end-to-end with a backend response.
- Basic history and preferences work reliably.
- Latency under acceptable thresholds for synchronous calls.

---

## Phase 2: Async Jobs + Object Storage

**Goal**: Introduce asynchronous processing for slow tasks and add storage for images.

**Architecture**
```
iOS (Swift) -> FastAPI -> PostgreSQL
                     -> Redis (queue)
                     -> Worker process
                     -> MinIO/S3 (images)
```

**Scope**
- Add Redis for queueing and rate limits.
- Add worker process for background jobs (ARQ or Celery).
- Add MinIO/S3 for scan images and contribution assets.
- Introduce job status tracking (`queued`, `processing`, `completed`, `failed`).

**New/Updated Endpoints**
- `POST /v1/scans/plate` (async): enqueue, return `jobId`.
- `GET /v1/scans/{jobId}`: poll for status + results.
- `POST /v1/scans/barcode` (can stay sync).
- Signed upload URLs for images (if needed).

**Data Model Additions**
- `scan_jobs` or status fields on `scans`.
- Image URL fields on `scans`.

**Operational Needs**
- Two containers (api + worker).
- Redis and object storage.
- Basic retry and failure handling.

**Exit Criteria**
- Long-running scans are reliable without blocking the API.
- Jobs complete with clear status and error handling.
- Images persist outside the API container.

---

## Phase 3: Catalog ETL + Contributions + Scale

**Goal**: Add catalog ingestion, deltas, and user contribution pipeline.

**Architecture**
```
iOS (Swift) -> FastAPI -> PostgreSQL
                     -> Redis (queue/cache)
                     -> Worker processes
                     -> MinIO/S3
                     -> ETL + scheduled jobs
```

**Scope**
- ETL pipeline to ingest `all_products_enriched_normalized.json`.
- Catalog delta generation for client sync.
- Contribution workflow (OCR, validation, moderation queue).
- Optional caching layer for hot product lookups.

**New Endpoints**
- `GET /v1/catalog/delta?since=<version>`.
- `POST /v1/catalog/contributions`.
- `GET /v1/catalog/contributions/{id}`.

**Data Model Additions**
- `products`
- `product_contributions`
- `catalog_versions`
- Audit/log tables as needed

**Operational Needs**
- Scheduled jobs (cron or task scheduler).
- Larger storage and retention policies.
- Monitoring beyond basic logs (Sentry or similar).

**Exit Criteria**
- Catalog updates and deltas are stable.
- Contributions flow from intake to approval.
- Backend handles higher traffic and larger datasets.

---

## Notes

- Each phase is designed to be independently shippable.
- Avoid building Phase 2 or 3 mechanics until Phase 1 usage is validated.
- The iOS app can stay "client-first" throughout, but backend complexity should only grow as needed.
