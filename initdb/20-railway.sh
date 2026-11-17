#!/bin/bash
# Runs once, when the database is first created (docker-entrypoint-initdb.d),
# after the image's 10_bootstrap_paradedb.sh, which creates pg_search, vector,
# pg_ivm, postgis, fuzzystrmatch and pg_stat_statements in template1 and in
# $POSTGRES_DB, and pg_cron in "postgres".
#
# The image's own auto-tuning sizes memory from the host it sees, which on a
# shared cloud host can mean many GB of shared_buffers. The wrapper turns it off
# (PDB_TUNE=false) and sets fixed, modest values here with ALTER SYSTEM
# (postgresql.auto.conf), so they can be changed later with ALTER SYSTEM.
# Set PDB_TUNE=true before the first deploy to use ParadeDB's auto-tuning instead.
set -euo pipefail

if [ "${PDB_TUNE:-false}" != "true" ]; then
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
ALTER SYSTEM SET shared_buffers = '${PG_SHARED_BUFFERS:-512MB}';
ALTER SYSTEM SET effective_cache_size = '${PG_EFFECTIVE_CACHE_SIZE:-1536MB}';
ALTER SYSTEM SET maintenance_work_mem = '${PG_MAINTENANCE_WORK_MEM:-256MB}';
ALTER SYSTEM SET work_mem = '${PG_WORK_MEM:-16MB}';
ALTER SYSTEM SET max_worker_processes = '${PG_MAX_WORKER_PROCESSES:-16}';
ALTER SYSTEM SET max_parallel_workers = '${PG_MAX_PARALLEL_WORKERS:-8}';
ALTER SYSTEM SET max_parallel_workers_per_gather = '${PG_MAX_PARALLEL_WORKERS_PER_GATHER:-2}';
ALTER SYSTEM SET max_parallel_maintenance_workers = '${PG_MAX_PARALLEL_MAINTENANCE_WORKERS:-4}';
SQL
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -Atc \
  "SELECT 'paradedb: ready in ${POSTGRES_DB}: ' || string_agg(extname || ' ' || extversion, ', ' ORDER BY extname) FROM pg_extension"
