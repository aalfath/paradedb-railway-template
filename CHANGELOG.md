# Changelog

## 0.26.7-pg18 (2026-11-17)

First release.

- ParadeDB 0.26.7 on PostgreSQL 18.7 (Debian trixie): `paradedb/paradedb:0.26.7-pg18@sha256:f3ded923eb3c9a0d051f916286b7b031f40bb9bb276c8db20bdb0d6640014dce` (built 2026-11-16).
- Data on a volume at `/var/lib/postgresql` (`PGDATA=/var/lib/postgresql/18/docker`).
- On first start the image creates `pg_search`, `vector`, `pg_ivm`, `postgis`, `fuzzystrmatch` and `pg_stat_statements` in the default database and `template1`, and `pg_cron` in `postgres`.
- Memory and parallelism set once with `ALTER SYSTEM` on first start (`shared_buffers=512MB`, `effective_cache_size=1536MB`, `maintenance_work_mem=256MB`, `work_mem=16MB`, 16 worker processes); the image's host-based auto-tuning is off unless `PDB_TUNE=true`.
- On every start: `ALTER EXTENSION pg_search UPDATE` and `ALTER EXTENSION vector UPDATE` where the installed version is older than the image's.
- Health endpoint `GET /healthz` on `PORT` (8080), backed by `pg_isready`.
- Dynamic shared memory in the data directory (`dynamic_shared_memory_type=mmap`).
- Self-signed TLS certificate generated on first start and renewed before expiry.
- SIGTERM from Railway becomes a fast Postgres shutdown.
- README: Deploy on Railway button for the template `paradedb-1`.
