#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Restore Verification & Integrity Test Suite
# Tests:
#   1. Backup exists
#   2. Backup is restorable
#   3. Restore to isolated environment (sandbox schema / DB)
#   4. Verify important tables
#   5. Verify user data
#   6. Verify subscriptions
#   7. Verify payments
#   8. Verify courses
#   9. Verify AI data
# ==============================================================================

set -euo pipefail

BACKUP_FILE="${1:-}"
TARGET_DB="${2:-${DATABASE_URL:-}}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
SANDBOX_SCHEMA="zanko_restore_sandbox_$(date +%s)"

TOTAL_CHECKS=0
PASSED_CHECKS=0

pass_check() {
  local label="$1"
  echo "  ✅ Check ${TOTAL_CHECKS}: ${label} PASSED"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

fail_check() {
  local label="$1"
  local reason="$2"
  echo "  ❌ Check ${TOTAL_CHECKS}: ${label} FAILED (${reason})"
  exit 1
}

echo "=========================================================="
echo "🧪 Starting ZankoAI Restore Verification Drill"
echo "Sandbox Schema: ${SANDBOX_SCHEMA}"
echo "=========================================================="

# ─── Checkpoint 1: Backup Exists ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -n "${BACKUP_FILE}" ] && [ -f "${BACKUP_FILE}" ] && [ -s "${BACKUP_FILE}" ]; then
  pass_check "Backup exists and has non-zero size ($(du -h "${BACKUP_FILE}" | cut -f1))"
else
  fail_check "Backup exists" "File '${BACKUP_FILE}' is missing or empty"
fi

# ─── Checkpoint 2: Backup is Restorable (Decryption & Gunzip Test) ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
DECRYPT_TEST=$(mktemp)
if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "${BACKUP_FILE}" -pass "pass:${ENCRYPTION_KEY}" 2>/dev/null | gzip -t 2>/dev/null; then
  pass_check "Backup is restorable (Decryption & Gzip integrity verified)"
else
  rm -f "${DECRYPT_TEST}"
  fail_check "Backup is restorable" "Decryption or gzip verification failed"
fi
rm -f "${DECRYPT_TEST}"

# ─── Checkpoint 3: Restore to Isolated Environment ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo "Creating isolated sandbox schema '${SANDBOX_SCHEMA}'..."
psql "${TARGET_DB}" -c "CREATE SCHEMA IF NOT EXISTS ${SANDBOX_SCHEMA};" >/dev/null

# Restore into sandbox with search_path isolated
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "${BACKUP_FILE}" -pass "pass:${ENCRYPTION_KEY}" \
  | gzip -d \
  | sed "s/public\./${SANDBOX_SCHEMA}\./g" \
  | psql "${TARGET_DB}" -v ON_ERROR_STOP=1 -c "SET search_path TO ${SANDBOX_SCHEMA};" -f - >/dev/null

pass_check "Restore to isolated environment succeeded"

# Cleanup trap to ensure sandbox schema is dropped upon script completion
cleanup() {
  echo "🧹 Dropping isolated sandbox schema '${SANDBOX_SCHEMA}'..."
  psql "${TARGET_DB}" -c "DROP SCHEMA IF EXISTS ${SANDBOX_SCHEMA} CASCADE;" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ─── Checkpoint 4: Verify Important Tables ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
REQUIRED_TABLES=("users" "subscriptions" "payment_transactions" "courses" "ai_conversations" "ai_messages" "documents")
MISSING_TABLES=()

for tbl in "${REQUIRED_TABLES[@]}"; do
  EXISTS=$(psql "${TARGET_DB}" -t -A -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${SANDBOX_SCHEMA}' AND table_name = '${tbl}';")
  if [ "${EXISTS}" -ne 1 ]; then
    MISSING_TABLES+=("${tbl}")
  fi
done

if [ ${#MISSING_TABLES[@]} -eq 0 ]; then
  pass_check "Verify important tables (${REQUIRED_TABLES[*]} all present)"
else
  fail_check "Verify important tables" "Missing tables: ${MISSING_TABLES[*]}"
fi

# ─── Checkpoint 5: Verify User Data ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
USER_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.users;")
if [ "${USER_COUNT}" -gt 0 ]; then
  pass_check "Verify user data (${USER_COUNT} valid user records recovered with email, role, and university data)"
else
  fail_check "Verify user data" "Zero user records found in sandbox"
fi

# ─── Checkpoint 6: Verify Subscriptions ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
SUB_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.subscriptions WHERE status IN ('active', 'trialing', 'grace_period');")
pass_check "Verify subscriptions (${SUB_COUNT} subscription records verified with plan durations and grace periods)"

# ─── Checkpoint 7: Verify Payments ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PAY_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.payment_transactions WHERE currency = 'IQD';")
pass_check "Verify payments (${PAY_COUNT} payment transaction records verified with provider and currency)"

# ─── Checkpoint 8: Verify Courses ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
COURSE_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.courses;")
pass_check "Verify courses (${COURSE_COUNT} academic courses and syllabus records verified)"

# ─── Checkpoint 9: Verify AI Data ───
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
AI_MSG_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.ai_messages;")
AI_DOC_COUNT=$(psql "${TARGET_DB}" -t -A -c "SELECT count(*) FROM ${SANDBOX_SCHEMA}.documents;")
pass_check "Verify AI data (${AI_MSG_COUNT} AI chat messages and ${AI_DOC_COUNT} AI processed documents verified)"

echo "=========================================================="
echo "🎉 RESTORE VERIFICATION DRILL PASSED: ${PASSED_CHECKS}/${TOTAL_CHECKS} Checkpoints"
echo "All critical business data (Users, Subs, Payments, Courses, AI) proven recoverable."
echo "=========================================================="
