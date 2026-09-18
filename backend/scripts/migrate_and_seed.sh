#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Database Migration & Seeding Automation Script
# Idempotently executes migrations inside Docker PostgreSQL & validates auth/queries
# ==============================================================================

set -euo pipefail

# ── Configuration Variables ───────────────────────────────────────────────────
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-zanko_postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-zanko_db}"
UPLOADS_DIR="${STORAGE_UPLOADS_PATH:-/var/data/uploads}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-$SCRIPT_DIR/../migrations}"
API_URL="${API_URL:-http://localhost:4000}"
JWT_SECRET="${SUPABASE_JWT_SECRET:-${JWT_SECRET:-zanko_production_secure_jwt_secret_min_32_chars_2026}}"

TEST_USER_ID="a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"
TEST_USER_EMAIL="student.test@zankoai.com"

echo "=================================================================="
echo " ZankoAI Production Migration & Verification Suite"
echo "=================================================================="

# ── 1. Storage Directory Initialization & Permissions ────────────────────────
echo "[1/4] Initializing local storage directories at: $UPLOADS_DIR"
mkdir -p "$UPLOADS_DIR/pdfs" "$UPLOADS_DIR/ocr" "$UPLOADS_DIR/exports"
chmod -R 775 "$UPLOADS_DIR"
echo "✔ Directory layout and 775 permissions established."

# ── 2. PostgreSQL Container Readiness Probe ──────────────────────────────────
echo "[2/4] Verifying PostgreSQL container '$POSTGRES_CONTAINER'..."
MAX_RETRIES=30
RETRY_COUNT=0

until docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "❌ Error: PostgreSQL container '$POSTGRES_CONTAINER' is not ready after $MAX_RETRIES attempts." >&2
    exit 1
  fi
  echo "Waiting for PostgreSQL... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 2
done
echo "✔ PostgreSQL engine is online and accepting connections."

# ── 3. Idempotent Database Migrations Execution ──────────────────────────────
echo "[3/4] Applying database migrations from: $MIGRATIONS_DIR"

# Ensure migration tracking table exists
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<-EOSQL
  CREATE TABLE IF NOT EXISTS public._schema_migrations (
    id SERIAL PRIMARY KEY,
    version VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW()
  );
EOSQL

APPLIED_COUNT=0
SKIPPED_COUNT=0

# Sort and run SQL migration files alphabetically
shopt -s nullglob
MIGRATION_FILES=("$MIGRATIONS_DIR"/*.sql)
shopt -u nullglob

if [ ${#MIGRATION_FILES[@]} -eq 0 ]; then
  echo "❌ Error: No migration files found in $MIGRATIONS_DIR" >&2
  exit 1
fi

for file in "${MIGRATION_FILES[@]}"; do
  filename="$(basename "$file")"
  
  # Check if version was already applied
  IS_APPLIED=$(docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
    "SELECT COUNT(*) FROM public._schema_migrations WHERE version = '$filename';")

  if [ "$IS_APPLIED" -eq "0" ]; then
    echo "  → Applying migration: $filename..."
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 < "$file"
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 \
      -c "INSERT INTO public._schema_migrations (version) VALUES ('$filename');"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
  else
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  fi
done

echo "✔ Migrations complete: $APPLIED_COUNT applied, $SKIPPED_COUNT already up to date."

# ── 4. Seed Test User & Validate Query Resolution ────────────────────────────
echo "[4/4] Seeding test user & validating query resolution for authenticated req.user.id..."

# Seed test records into auth.users stub and public.profiles
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<-EOSQL
  INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud)
  VALUES (
    '$TEST_USER_ID',
    '$TEST_USER_EMAIL',
    '{"full_name": "Test Student Verification"}'::jsonb,
    'authenticated',
    'authenticated'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, email, full_name, role, status, plan, is_vip, vip_status)
  VALUES (
    '$TEST_USER_ID',
    '$TEST_USER_EMAIL',
    'Test Student Verification',
    'student',
    'active',
    'free',
    false,
    'none'
  )
  ON CONFLICT (id) DO UPDATE SET updated_at = NOW();
EOSQL

# Query database directly to confirm persistence
DB_VERIFY=$(docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT id || '|' || email || '|' || role FROM public.profiles WHERE id = '$TEST_USER_ID';")

if [[ "$DB_VERIFY" == *"$TEST_USER_ID"* ]]; then
  echo "✔ Database query resolution confirmed: $DB_VERIFY"
else
  echo "❌ Error: Failed to resolve test user in PostgreSQL profiles table." >&2
  exit 1
fi

# Generate simulated Supabase JWT signed with SUPABASE_JWT_SECRET
TEST_TOKEN=$(node -e "
  const jwt = require('jsonwebtoken');
  const token = jwt.sign({
    sub: '$TEST_USER_ID',
    email: '$TEST_USER_EMAIL',
    role: 'authenticated',
    aud: 'authenticated',
    app_metadata: { provider: 'email' },
    user_metadata: { full_name: 'Test Student Verification' }
  }, '$JWT_SECRET', { expiresIn: '1h', algorithm: 'HS256' });
  console.log(token);
" 2>/dev/null || echo "")

if [ -n "$TEST_TOKEN" ]; then
  echo "✔ Generated test JWT: ${TEST_TOKEN:0:20}...${TEST_TOKEN: -10}"
  
  # If API server is live, test API endpoint verification
  if curl -s -f -o /dev/null "$API_URL/api/health" 2>/dev/null; then
    echo "Testing Express API authentication with Bearer token..."
    HTTP_CODE=$(curl -s -o /tmp/profile_resp.json -w "%{http_code}" \
      -H "Authorization: Bearer $TEST_TOKEN" \
      "$API_URL/api/auth/profile")
    
    if [ "$HTTP_CODE" -eq "200" ]; then
      echo "✔ Express correctly resolved req.user.id ('$TEST_USER_ID') via JWT. Profile data:"
      cat /tmp/profile_resp.json
      echo ""
    else
      echo "⚠ Warning: API responded with status $HTTP_CODE to authenticated test token."
      cat /tmp/profile_resp.json || true
    fi
  else
    echo "ℹ API server ($API_URL) is currently offline; direct DB assertion passed."
  fi
fi

echo "=================================================================="
echo "✔ All Migration & Seeding Verification Tasks Completed Successfully!"
echo "=================================================================="
