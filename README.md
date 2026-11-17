# ParadeDB on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/paradedb-1?utm_medium=integration&utm_source=button&utm_campaign=paradedb)

Railway template for [ParadeDB](https://www.paradedb.com/), PostgreSQL with the `pg_search` extension for BM25 full-text search, plus vector search and fast aggregations, all in SQL. It runs ParadeDB 0.26.7 on PostgreSQL 18.

This repo is what the template builds: a `Dockerfile` that pins the official image `paradedb/paradedb:0.26.7-pg18` by digest, a start script (`railway-entrypoint.sh`), a tiny health endpoint (`railway-health.py`) and a first-start script (`initdb/20-railway.sh`).

## What you get

- **ParadeDB 0.26.7 on PostgreSQL 18.7** (official `paradedb/paradedb` image, Debian trixie), pinned by version and digest.
- **Extensions ready on first boot** (created by the image in the default database and in `template1`, so every new database gets them too): `pg_search`, `vector` (pgvector), `pg_ivm`, `postgis`, `fuzzystrmatch` and `pg_stat_statements`, plus `pg_cron` in the `postgres` database.
- **Persistent data** on a Railway volume mounted at `/var/lib/postgresql` (`PGDATA=/var/lib/postgresql/18/docker`).
- **Generated password:** `POSTGRES_PASSWORD` is a random 32-character secret. There is no default password.
- **Health check:** `GET /healthz` on the service's `PORT` (8080) answers 200 only once Postgres accepts connections, so Railway switches traffic over only to a working database. The endpoint has no public domain and returns no data.
- **TLS:** a self-signed certificate is generated on first start, kept on the volume and renewed 30 days before it expires. Clients using `sslmode=prefer` or `require` get an encrypted connection.
- **Predictable memory settings:** the image's auto-tuning sizes memory from the host it sees, which on a shared cloud host can be far more than your service has. This template turns it off and sets `shared_buffers=512MB`, `effective_cache_size=1536MB`, `maintenance_work_mem=256MB`, `work_mem=16MB` and modest parallel-worker limits on first start with `ALTER SYSTEM`, so you can change them later.
- **Extension updates on redeploy:** after an image update, the start script runs `ALTER EXTENSION pg_search UPDATE` and `ALTER EXTENSION vector UPDATE` in every database where the installed version is older than the image's, as ParadeDB's upgrade guide asks.
- **Private and public access:** other services connect over Railway's private network with `${{ParadeDB.DATABASE_URL}}`. A TCP proxy on port 5432 gives `DATABASE_PUBLIC_URL` for tools outside Railway.
- **Clean redeploys:** the start script turns Railway's SIGTERM into a fast shutdown, so Postgres checkpoints and stops within the 60 s draining window.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Superuser name |
| `POSTGRES_PASSWORD` | `${{secret(32)}}` | Generated at deploy time |
| `POSTGRES_DB` | `railway` | Default database, created with the extensions |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` | references | libpq-style connection settings for other services |
| `DATABASE_URL` | private URL | `postgresql://…@${{RAILWAY_PRIVATE_DOMAIN}}:5432/…` |
| `DATABASE_PUBLIC_URL` | public URL | Through the TCP proxy |
| `PORT` | `8080` | Health endpoint only; Postgres always listens on 5432 |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Time Postgres gets to shut down on redeploy |

Optional, not in the template (add them to the service before the first deploy if you need them):

- `PG_SHARED_BUFFERS` (default `512MB`), `PG_EFFECTIVE_CACHE_SIZE` (`1536MB`), `PG_MAINTENANCE_WORK_MEM` (`256MB`), `PG_WORK_MEM` (`16MB`), `PG_MAX_WORKER_PROCESSES` (`16`), `PG_MAX_PARALLEL_WORKERS` (`8`), `PG_MAX_PARALLEL_WORKERS_PER_GATHER` (`2`), `PG_MAX_PARALLEL_MAINTENANCE_WORKERS` (`4`): used only when the database is first created. To change them later, run `ALTER SYSTEM SET work_mem = '64MB';` and redeploy.
- `PDB_TUNE=true`: use ParadeDB's own auto-tuning instead of the values above (first start only).
- `PG_DYNAMIC_SHARED_MEMORY_TYPE` (default `mmap`): set to `posix` to use `/dev/shm` instead.
- `SSL_CERT_DAYS` (default `820`): lifetime of the generated certificate.

## Connect

From another Railway service: set `DATABASE_URL=${{ParadeDB.DATABASE_URL}}`.

From your machine: copy `DATABASE_PUBLIC_URL` from the service's Variables tab, then

```sh
psql "$DATABASE_PUBLIC_URL"
```

```sql
CREATE TABLE items (id serial PRIMARY KEY, description text, rating int);
INSERT INTO items (description, rating) VALUES
  ('Ergonomic metal keyboard', 4), ('Plastic keyboard', 3), ('Sleek running shoes', 5);
CREATE INDEX items_idx ON items USING bm25 (id, description, rating);
SELECT description, pdb.score(id) FROM items WHERE description ||| 'keyboard' ORDER BY 2 DESC;
```

See ParadeDB's guides to [create your first index](https://www.paradedb.com/docs/start/create-your-first-index) and [run queries](https://www.paradedb.com/docs/start/run-queries).

## Backups

Railway can snapshot the volume (service → Volume → Backups). For logical backups, run `pg_dump "$DATABASE_PUBLIC_URL" > backup.sql` from your machine.

## Updates

Deployers get Railway's "update available" notice when this repo's `main` branch changes. Each change is listed in [CHANGELOG.md](CHANGELOG.md); read it before you apply an update. Minor ParadeDB updates stay on PostgreSQL 18 and are applied in place: the start script runs `ALTER EXTENSION ... UPDATE` on the next start. A PostgreSQL major-version change would need a dump and restore, and the changelog will say so first.

ParadeDB is licensed under AGPL-3.0 by ParadeDB, Inc. This wrapper is MIT-licensed.
