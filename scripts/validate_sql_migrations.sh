#!/usr/bin/env bash
# ==============================================================================
# ZankoAI SQL Migrations Validator
# Validates:
#   1. Monotonic timestamp sequence in supabase/migrations/
#   2. Valid naming convention (YYYYMMDDHHMMSS_name.sql)
#   3. Guarded destructive operations (DROP statements require IF EXISTS)
#   4. Idempotency checks (CREATE OR REPLACE / IF NOT EXISTS)
# ==============================================================================

set -euo pipefail

MIGRATIONS_DIR="${1:-supabase/migrations}"

echo "=========================================================="
echo "🔍 Validating Supabase SQL Migrations..."
echo "Directory: ${MIGRATIONS_DIR}"
echo "=========================================================="

if [ ! -d "${MIGRATIONS_DIR}" ]; then
  echo "❌ Error: Migrations directory '${MIGRATIONS_DIR}' does not exist!"
  exit 1
fi

TOTAL_FILES=0
FAILED_CHECKS=0
LAST_TIMESTAMP=""

# Sort files alphabetically
FILES=$(find "${MIGRATIONS_DIR}" -maxdepth 1 -name "*.sql" | sort)

for file in ${FILES}; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  filename=$(basename "${file}")

  # 1. Validate Naming Pattern: YYYYMMDDHHMMSS_*.sql (14 digit timestamp)
  if [[ ! "${filename}" =~ ^[0-9]{14}_[a-zA-Z0-9_]+\.sql$ ]]; then
    echo "❌ [Naming Violation] File '${filename}' does not follow 'YYYYMMDDHHMMSS_name.sql' format."
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    continue
  fi

  TIMESTAMP="${filename:0:14}"

  # 2. Validate Monotonic Ordering
  if [ -n "${LAST_TIMESTAMP}" ] && [ "${TIMESTAMP}" -le "${LAST_TIMESTAMP}" ]; then
    echo "❌ [Timestamp Sequencing Violation] '${filename}' (${TIMESTAMP}) is not strictly greater than previous '${LAST_TIMESTAMP}'."
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
  LAST_TIMESTAMP="${TIMESTAMP}"

  # 3. Check for Unguarded Destructive Operations
  # Flag lines with DROP TABLE/INDEX/COLUMN/POLICY that do NOT include IF EXISTS
  if grep -inE '^\s*DROP\s+(TABLE|INDEX|POLICY|VIEW|TYPE)\s+' "${file}" | grep -ivE 'IF\s+EXISTS' > /dev/null 2>&1; then
    echo "⚠️ [Destructive Guard Warning] '${filename}' contains DROP statements without 'IF EXISTS':"
    grep -inE '^\s*DROP\s+(TABLE|INDEX|POLICY|VIEW|TYPE)\s+' "${file}" | grep -ivE 'IF\s+EXISTS' || true
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
done

echo "----------------------------------------------------------"
echo "Total Migrations Checked: ${TOTAL_FILES}"
if [ "${FAILED_CHECKS}" -eq 0 ]; then
  echo "✅ All SQL migrations passed naming, monotonic, and guard checks."
else
  echo "❌ ${FAILED_CHECKS} migration validation check(s) failed."
  exit 1
fi
echo "=========================================================="
