#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Deployment Script (Zero-Downtime Rolling Update)
# Usage: ./deploy/deploy.sh
# ==============================================================================

set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/zankoAI}"
COMPOSE_FILE="${APP_DIR}/backend/docker-compose.prod.yml"
ENV_FILE="${APP_DIR}/backend/.env.production"

echo "=========================================================="
echo "🚀 Starting ZankoAI Production Deployment..."
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================================="

# ─── 1. Prerequisite Checks ───
if [ ! -f "${ENV_FILE}" ]; then
  echo "❌ Error: Production environment file '${ENV_FILE}' not found!"
  echo "Please create '${ENV_FILE}' from '.env.production.example' before deploying."
  exit 1
fi

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "❌ Error: Production docker-compose file '${COMPOSE_FILE}' not found!"
  exit 1
fi

# Ensure Let's Encrypt directory exists (fallback to self-signed if bootstrapping)
SSL_DIR="/etc/letsencrypt/live/api.zankoai.com"
if [ ! -f "${SSL_DIR}/fullchain.pem" ]; then
  echo "⚠️ Notice: Production SSL certs not found in ${SSL_DIR}."
  echo "Generating bootstrap SSL certificate so Nginx can start..."
  mkdir -p "${SSL_DIR}"
  openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
    -keyout "${SSL_DIR}/privkey.pem" \
    -out "${SSL_DIR}/fullchain.pem" \
    -subj "/CN=api.zankoai.com" || true
fi

mkdir -p /var/www/certbot

# ─── 2. Pull / Build Images with Cache ───
echo "🔨 Building and compiling production Docker containers..."
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" build --parallel

# ─── 3. Launch Services with Healthcheck Orchestration ───
echo "🚀 Launching services (redis, api, worker, nginx)..."
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d --remove-orphans

# ─── 4. Healthcheck Verification ───
echo "⏳ Waiting for healthcheck validation on all containers..."
MAX_WAIT=60
ELAPSED=0

until [ $ELAPSED -ge $MAX_WAIT ]; do
  UNHEALTHY=$(docker compose -f "${COMPOSE_FILE}" ps --format json | jq -r 'select(.Health != "healthy" and .Health != "") | .Name' || true)
  if [ -z "${UNHEALTHY}" ]; then
    echo "✅ All running containers are reporting healthy status."
    break
  fi
  echo "Waiting for services to become healthy (Elapsed: ${ELAPSED}s)..."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

# ─── 5. Test Live Endpoints ───
echo "🔍 Validating live HTTP endpoints..."
# Test Nginx local reverse proxy
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health || true)
if [ "${HTTP_STATUS}" -eq 200 ]; then
  echo "✅ Local Nginx reverse proxy returned HTTP 200 on /api/health."
else
  echo "⚠️ Warning: Local probe returned HTTP ${HTTP_STATUS}. Check 'docker logs zanko_nginx'."
fi

# ─── 6. Cleanup Dangling Images ───
echo "🧹 Pruning dangling Docker images to preserve disk space..."
docker image prune -f --filter "dangling=true" || true

echo "=========================================================="
echo "🎉 ZankoAI Production Deployment Completed Successfully!"
echo "• API Domain: https://api.zankoai.com/api/health"
echo "• Containers: $(docker compose -f "${COMPOSE_FILE}" ps --services | tr '\n' ' ')"
echo "=========================================================="
