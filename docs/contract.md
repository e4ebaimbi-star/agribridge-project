# AgriBridge platform contract

Last updated: <date> by <name>. Any change to this file must be announced in the team channel.

## 1. Images

| Component | Image name | Base | Listens on |
|---|---|---|---|
| API | agribridge-api | node:20.11-alpine | 3000 |
| Web | agribridge-web | nginx:1.27-alpine | 80 |

- Registry: <ECR repo URL or GHCR path, decided Day 1>
- Tag format: the full git commit SHA (`git rev-parse HEAD`). Never `latest`.
- The same image is used in Compose, the pipeline and Helm. Nothing is rebuilt per environment.
- Runs as non-root user `node` (API).

## 2. Build-time configuration (baked in, identical everywhere)

| Build arg | Origin | Surfaces at |
|---|---|---|
| APP_VERSION | release version | /version, /metrics build info |
| GIT_SHA | `git rev-parse HEAD` | /version, /metrics, OCI label |
| BUILD_DATE | UTC timestamp | /version, OCI label |
| IMAGE_TAG | tag it is published under | /version |

The web image has no build-time configuration at all.

## 3. Runtime configuration

Non-secret (plain config, differs per environment): NODE_ENV, PORT, LOG_LEVEL,
TRUST_PROXY, SHUTDOWN_GRACE_MS (default 10000), PGHOST, PGPORT, PGDATABASE,
PGUSER, PGSSL, PG_POOL_*, PG_*_TIMEOUT_MS, REDIS_ENABLED, REDIS_URL,
REDIS_REQUIRED, CACHE_TTL_SECONDS, TOKEN_TTL_SECONDS, COOKIE_NAME,
COOKIE_SECURE, BCRYPT_ROUNDS, RUN_MIGRATIONS, SEED_DEMO_DATA.

Secret (secrets manager only, never in git, images, logs or values files):
PGPASSWORD, JWT_SECRET, SEED_PASSWORD.

Web runtime variable: `API_UPSTREAM` (host:port of the API, used by the nginx proxy).

## 4. Ports and routing

| Route | Served by | Notes |
|---|---|---|
| `/` and all non-API paths | web (nginx) | SPA fallback to index.html |
| `/api/*` | API | Same origin as the web, so the cookie works |
| `/healthz`, `/readyz`, `/metrics`, `/version` | API, at the root | Not under /api. Probes and scrapes hit the API directly. |

- Compose: nginx proxies `/api` to `API_UPSTREAM` (api:3000). API port 3000 is also published for probes and metrics.
- Cluster: the ingress routes `/api` to the API Service and `/` to the web Service. The nginx proxy block goes unused there. Same image either way.

## 5. Health, shutdown and posture

- Liveness: `/healthz`. Touches no dependency.
- Readiness: `/readyz`. 503 when the database is down. Reports a `degraded` flag when only the cache is lost.
- Shutdown rule: supervisor grace must exceed `SHUTDOWN_GRACE_MS`.
  - Compose: `stop_grace_period: 30s` with `SHUTDOWN_GRACE_MS=20000`.
  - Cluster: `terminationGracePeriodSeconds` > SHUTDOWN_GRACE_MS, plus a short preStop sleep (suggestion for P3).
- Startup note: the API waits for the database (up to 30 attempts, about 2 s apart) and may not answer HTTP until it connects. The chart needs a `startupProbe` or generous initial delay.
- Migrations: Compose runs them in the API (`RUN_MIGRATIONS=true`). In the cluster they run once as a Helm hook Job, and the app pods use `RUN_MIGRATIONS=false`.
- Redis posture: <local/staging/prod values and the justification>

## 6. Local environment

    cp .env.compose.example .env
    docker compose up --build

| URL | What |
|---|---|
| http://localhost:8080 | the app (same origin) |
| http://localhost:3000/readyz | readiness |
| http://localhost:3000/version | running version and commit |

- Local cookie: `COOKIE_SECURE=false` (HTTP only). Never in staging or prod.
- Data persists in the named volume `pgdata`. `docker compose down` keeps it, `docker compose down -v` deletes it.

## 7. Terraform outputs consumed elsewhere (P2 fills in)

| Output | Consumed by |
|---|---|
| cluster_name | CI deploy job, `make kubeconfig` |
| rds_endpoint | Helm values (PGHOST) |
| redis_endpoint | Helm values (REDIS_URL) |
| secret names/ARNs | ExternalSecret manifests |
| ci_role_arn | GitHub Actions OIDC |

## 8. Chart values keys (P3 fills in)

<list each values key, what it controls, and which values file sets it>