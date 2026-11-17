# ParadeDB 0.26.7 (pg_search) on PostgreSQL 18, official image pinned by digest.
FROM paradedb/paradedb:0.26.7-pg18@sha256:f3ded923eb3c9a0d051f916286b7b031f40bb9bb276c8db20bdb0d6640014dce

# PostgreSQL 18 data layout. Mount the Railway volume at /var/lib/postgresql.
ENV PGDATA=/var/lib/postgresql/18/docker

# 20-railway.sh runs once, after the image's 10_bootstrap_paradedb.sh.
COPY initdb/ /docker-entrypoint-initdb.d/
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY railway-health.py /usr/local/bin/railway-health.py
RUN chmod 0755 /usr/local/bin/railway-entrypoint.sh /usr/local/bin/railway-health.py /docker-entrypoint-initdb.d/20-railway.sh

EXPOSE 5432
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD []
