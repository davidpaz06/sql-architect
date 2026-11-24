# docker/db.Dockerfile
# PostgreSQL 18 plus extensions that are not in the official image. Keep only the packages you use.
# Package names come from the PGDG apt repository that the official image already configures.
FROM postgres:18

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-18-pgvector \
      postgresql-18-postgis-3 \
      postgresql-18-cron \
      postgresql-18-partman \
 && rm -rf /var/lib/apt/lists/*
