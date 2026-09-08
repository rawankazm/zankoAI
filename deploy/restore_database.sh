#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Database Restore Utility
# Validates SHA-256 Checksum, Decrypts AES-256-CBC, and Restores via psql
# ==============================================================================

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path-to-encrypted-backup.sql.gz.enc> [target-database-url]"
  exit 1
fi

ENCRYPTED_BACKUP="$1"
TARGET_DB="${2:-${DATABASE_URL:-}}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

echo "=========================================================="
echo "🔄 Starting ZankoAI Production Database Restore..."
echo "Archive: ${ENCRYPTED_BACKUP}"
echo "=========================================================="

# ─── 1. Prerequisite Validations ───
if [ ! -f "${ENCRYPTED_BACKUP}" ]; then
  echo "❌ Error: Backup file '${ENCRYPTED_BACKUP}' not found!"
  exit 1
fi

if [ -z "${TARGET_DB}" ]; then
  echo "❌ Error: Target database URL not supplied and DATABASE_URL is not set!"
  exit 1
fi

if [ -z "${ENCRYPTION_KEY}" ]; then
  echo "❌ Error: BACKUP_ENCRYPTION_KEY environment variable is not defined!"
  exit 1
fi

# ─── 2. Cryptographic Digest Verification ───
CHECKSUM_FILE="${ENCRYPTED_BACKUP%.*.*}.sha256"
if [ ! -f "${CHECKSUM_FILE}" ]; then
  CHECKSUM_FILE="${ENCRYPTED_BACKUP}.sha256"
fi

if [ -f "${CHECKSUM_FILE}" ]; then
  echo "🔑 Verifying SHA-256 cryptographic checksum against ${CHECKSUM_FILE}..."
  EXPECTED_HASH=$(cat "${CHECKSUM_FILE}" | awk '{print $1}')
  ACTUAL_HASH=$(sha256sum "${ENCRYPTED_BACKUP}" | awk '{print $1}')
  
  if [ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]; then
    echo "🚨 CRITICAL INTEGRITY FAILURE: Checksum mismatch!"
    echo "Expected: ${EXPECTED_HASH}"
    echo "Actual:   ${ACTUAL_HASH}"
    echo "Restoration aborted to prevent corruption or replay attacks."
    exit 2
  fi
  echo "✅ Checksum matched: ${ACTUAL_HASH}"
else
  echo "⚠️ Warning: No .sha256 file found. Proceeding with decryption check..."
fi

# ─── 3. Decrypt & Restore Stream ───
DECRYPTED_FIFO=$(mktemp -u /tmp/zanko_restore_fifo.XXXXXX)
mkfifo -m 600 "${DECRYPTED_FIFO}"
trap 'rm -f "${DECRYPTED_FIFO}"' EXIT

echo "🔓 Decrypting and restoring into target PostgreSQL database..."
openssl enc -d -aes-256-cbc \
  -pbkdf2 \
  -iter 100000 \
  -in "${ENCRYPTED_BACKUP}" \
  -pass "pass:${ENCRYPTION_KEY}" \
  > "${DECRYPTED_FIFO}" &

# Gunzip and pipe directly into psql
gunzip -c "${DECRYPTED_FIFO}" | psql "${TARGET_DB}" --single-transaction --set ON_ERROR_STOP=on

echo "=========================================================="
echo "🎉 ZankoAI Database Restore Succeeded Without Errors!"
echo "=========================================================="
