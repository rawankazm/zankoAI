#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Automated Production Deployment Script
# Idempotent: clones/updates repo, configures env, builds containers, runs migrations
# ==============================================================================

set -e

echo "=== [1/5] Syncing Repository ==="
mkdir -p /opt
if [ ! -d "/opt/zankoAI" ]; then
  git clone https://github.com/rawankazm/zankoAI.git /opt/zankoAI
fi
cd /opt/zankoAI
git fetch origin main
git reset --hard origin/main
cd backend

echo "=== [2/5] Configuring Production Environment ==="
cp -f .env.production.example .env.production
mkdir -p /var/data/uploads/pdfs /var/data/uploads/ocr /var/data/uploads/exports
chmod -R 775 /var/data/uploads

mkdir -p /var/www/certbot
if [ ! -f "/etc/letsencrypt/live/api.zankoai.com/fullchain.pem" ]; then
  mkdir -p /etc/letsencrypt/live/api.zankoai.com
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/letsencrypt/live/api.zankoai.com/privkey.pem \
    -out /etc/letsencrypt/live/api.zankoai.com/fullchain.pem \
    -subj "/CN=api.zankoai.com"
fi

echo "=== [3/5] Starting Docker Containers ==="
systemctl enable --now docker
if ! docker compose version >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y docker-compose-plugin || apt-get install -y docker-compose
fi

# Bring up dependencies first
docker compose -f docker-compose.prod.yml up -d --build postgres redis

# Wait up to 30s for postgres to be healthy
echo "Waiting for PostgreSQL and Redis to be healthy..."
for i in $(seq 1 15); do
  if docker exec zanko_postgres pg_isready -U postgres -d zanko_db >/dev/null 2>&1; then
    echo "PostgreSQL is ready."
    break
  fi
  sleep 2
done

# Bring up API, Worker, Nginx, PostgREST
docker compose -f docker-compose.prod.yml up -d --build --force-recreate postgrest api worker nginx
docker compose -f docker-compose.prod.yml restart nginx

echo "=== [4/5] Running Migrations & Seeding ==="
chmod +x scripts/migrate_and_seed.sh
./scripts/migrate_and_seed.sh

echo "=== [5/5] Deployment Verification ==="
docker compose -f docker-compose.prod.yml ps
echo "ZankoAI Production Backend Successfully Deployed!"
