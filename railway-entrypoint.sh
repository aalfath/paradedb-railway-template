#!/bin/sh
# Railway wrapper for the official ParadeDB image.
# - health endpoint on $PORT (pg_isready over TCP) for Railway's health check
# - TLS with a self-signed certificate kept on the volume (renewed 30 days before expiry)
# - dynamic shared memory in the data directory, so parallel queries and index
#   builds aren't limited by the container's small /dev/shm
# - after an image update, ALTER EXTENSION ... UPDATE for pg_search and vector
# - fast, clean shutdown when Railway sends SIGTERM on redeploy
set -eu

# Railway's PGHOST/PGPORT point at the private domain; the image's init scripts
# must use the local socket, and Postgres itself always listens on 5432.
unset PGHOST PGPORT

export PGDATA="${PGDATA:-/var/lib/postgresql/18/docker}"
# Fixed memory settings come from initdb/20-railway.sh instead of the image's
# host-based auto-tuning. Set PDB_TUNE=true before the first deploy to use it.
export PDB_TUNE="${PDB_TUNE:-false}"

CERT_DIR="${SSL_CERT_DIR:-/var/lib/postgresql/certs}"
CERT_DAYS="${SSL_CERT_DAYS:-820}"
mkdir -p "$CERT_DIR"
if [ ! -s "$CERT_DIR/server.crt" ] || [ ! -s "$CERT_DIR/server.key" ] \
   || ! openssl x509 -checkend 2592000 -noout -in "$CERT_DIR/server.crt" >/dev/null 2>&1; then
  echo "railway-entrypoint: generating self-signed TLS certificate (${CERT_DAYS} days)"
  openssl req -new -x509 -nodes -days "$CERT_DAYS" -newkey rsa:2048 \
    -subj "/CN=${RAILWAY_PRIVATE_DOMAIN:-localhost}" \
    -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" >/dev/null 2>&1
fi
chown -R postgres:postgres "$CERT_DIR"
chmod 0700 "$CERT_DIR"
chmod 0600 "$CERT_DIR/server.key"

docker-entrypoint.sh postgres \
  -c port=5432 \
  -c listen_addresses='*' \
  -c ssl=on \
  -c ssl_cert_file="$CERT_DIR/server.crt" \
  -c ssl_key_file="$CERT_DIR/server.key" \
  -c dynamic_shared_memory_type="${PG_DYNAMIC_SHARED_MEMORY_TYPE:-mmap}" \
  "$@" &
pid=$!

# Health endpoint for Railway: GET /healthz on $PORT (default 8080).
python3 /usr/local/bin/railway-health.py &

# Once the real server listens on TCP (the first-start init server only uses the
# socket), bring pg_search and vector up to the versions in this image, as
# ParadeDB's upgrade guide asks after every image update. Errors are logged and
# never stop the database.
(
  export PGUSER="${POSTGRES_USER:-postgres}"
  i=0
  until pg_isready -q -h 127.0.0.1 -p 5432 -d postgres -t 2 >/dev/null 2>&1; do
    i=$((i + 1)); [ "$i" -gt 900 ] && exit 0; sleep 2
  done
  export PGHOST=/var/run/postgresql
  for db in $(psql -d postgres -Atc "SELECT datname FROM pg_database WHERE datallowconn" 2>/dev/null); do
    for ext in pg_search vector; do
      need=$(psql -d "$db" -Atc "SELECT 1 FROM pg_extension e JOIN pg_available_extensions a ON a.name = e.extname WHERE e.extname = '$ext' AND e.extversion IS DISTINCT FROM a.default_version" 2>/dev/null || true)
      if [ "$need" = "1" ]; then
        echo "railway-entrypoint: ALTER EXTENSION $ext UPDATE in database $db"
        psql -d "$db" -v ON_ERROR_STOP=1 -qc "ALTER EXTENSION $ext UPDATE" \
          || echo "railway-entrypoint: updating $ext in $db failed; see https://www.paradedb.com/docs/operate/deploy/upgrading"
      fi
    done
  done
) &

# Postgres treats SIGTERM as "smart" shutdown (waits for every client to leave);
# turn it into a fast shutdown so redeploys finish within the draining window.
trap 'kill -INT "$pid" 2>/dev/null || true' TERM INT

set +e
wait "$pid"; status=$?
while kill -0 "$pid" 2>/dev/null; do wait "$pid"; status=$?; done
exit "$status"
