#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Deployment Rollback Script
# Automatically reverts to previous stable git release / container build
# ==============================================================================

set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/zankoAI}"
COMPOSE_FILE="${APP_DIR}/backend/docker-compose.prod.yml"
ENV_FILE="${APP_DIR}/backend/.env.production"
ENV_BAK="${APP_DIR}/backend/.env.production.bak"

echo "=========================================================="
echo "🚨 INITIATING AUTOMATIC PRODUCTION ROLLBACK"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================================="

cd "${APP_DIR}"

# 1. Restore previous environment backup if available
if [ -f "${ENV_BAK}" ]; then
  echo "🔄 Restoring previous environment configuration..."
  cp "${ENV_BAK}" "${ENV_FILE}"
fi

# 2. Check git history and revert to previous stable commit if git is used
if git rev-parse --is-inside-work-tree &>/dev/null; then
  CURRENT_COMMIT=$(git rev-parse --short HEAD)
  PREVIOUS_COMMIT=$(git rev-parse --short HEAD~1 2>/dev/null || echo "")
  
  if [ -n "${PREVIOUS_COMMIT}" ]; then
    echo "🔄 Rolling back git codebase from ${CURRENT_COMMIT} to ${PREVIOUS_COMMIT}..."
    git checkout "${PREVIOUS_COMMIT}"
  fi
fi

# 3. Restart services using previous configuration
echo "🚀 Rebuilding and starting previous stable containers..."
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d --build --remove-orphans

# 4. Verify Health of Rolled-Back Instance
echo "⏳ Waiting for restored instance healthcheck..."
MAX_WAIT=45
ELAPSED=0
HEALTHY=false

until [ $ELAPSED -ge $MAX_WAIT ]; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health || true)
  if [ "${STATUS}" -eq 200 ]; then
    HEALTHY=true
    echo "✅ Rolled back instance is healthy and responding with HTTP 200!"
    break
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if [ "${HEALTHY}" = true ]; then
  echo "=========================================================="
  echo "✅ PRODUCTION ROLLBACK COMPLETED SUCCESSFULLY"
  echo "System restored to stable state. Inspect failure logs."
  echo "=========================================================="
  exit 0
else
  echo "❌ CRITICAL: Rollback instance failed healthcheck! Manual intervention required."
  exit 1
fi
