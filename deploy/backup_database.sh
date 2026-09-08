#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Database Automated Backup Script
# Strategy: Logical pg_dump + Gzip + AES-256-CBC Encryption + SHA-256 Checksum
# Target: Private Cloud Cold Storage (DigitalOcean Spaces / AWS S3)
# ==============================================================================

set -euo pipefail

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="${BACKUP_DIR:-/var/backups/zanko_db}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
STORAGE_BUCKET="${BACKUP_STORAGE_BUCKET:-s3://zanko-production-vault/db-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

echo "=========================================================="
echo "📦 Starting ZankoAI Production Database Backup..."
echo "Timestamp: ${TIMESTAMP}"
echo "=========================================================="

# ─── 1. Prerequisite Validations ───
if [ -z "${DATABASE_URL:-}" ]; then
  echo "❌ Error: DATABASE_URL environment variable is not defined!"
  exit 1
fi

if [ -z "${ENCRYPTION_KEY}" ]; then
  echo "❌ Error: BACKUP_ENCRYPTION_KEY environment variable is not defined!"
  echo "Refusing to create unencrypted database backups."
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

RAW_DUMP="${BACKUP_DIR}/zanko_db_${TIMESTAMP}.sql.gz"
ENCRYPTED_DUMP="${BACKUP_DIR}/zanko_db_${TIMESTAMP}.sql.gz.enc"
CHECKSUM_FILE="${BACKUP_DIR}/zanko_db_${TIMESTAMP}.sha256"

# ─── 2. Execute High-Fidelity Compressed Logical Dump ───
echo "🗄️ Dumping PostgreSQL public schema, schemas, extensions, and tables..."
# Flags:
# --clean: Include DROP statements before CREATE for clean restores
# --if-exists: Use IF EXISTS with DROP
# --no-owner: Do not set table ownership to facilitate restoration across environments
# --no-privileges: Prevent privilege grant conflicts
pg_dump "${DATABASE_URL}" \
  --format=plain \
  --schema=public \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  | gzip -9 > "${RAW_DUMP}"

DUMP_SIZE=$(du -h "${RAW_DUMP}" | cut -f1)
echo "✅ Logical dump completed: ${RAW_DUMP} (Size: ${DUMP_SIZE})"

# ─── 3. AES-256-CBC Encryption with PBKDF2 Key Derivation ───
echo "🔒 Encrypting backup with OpenSSL AES-256-CBC (PBKDF2 salt, 100,000 iterations)..."
openssl enc -aes-256-cbc \
  -salt \
  -pbkdf2 \
  -iter 100000 \
  -in "${RAW_DUMP}" \
  -out "${ENCRYPTED_DUMP}" \
  -pass "pass:${ENCRYPTION_KEY}"

# Securely wipe unencrypted raw dump from disk immediately
shred -u "${RAW_DUMP}" 2>/dev/null || rm -f "${RAW_DUMP}"
echo "✅ Encrypted backup generated: ${ENCRYPTED_DUMP}"

# ─── 4. Generate SHA-256 Cryptographic Digest ───
echo "🔑 Computing cryptographic SHA-256 checksum..."
sha256sum "${ENCRYPTED_DUMP}" | awk '{print $1}' > "${CHECKSUM_FILE}"
CHECKSUM=$(cat "${CHECKSUM_FILE}")
echo "✅ SHA-256: ${CHECKSUM}"

# ─── 5. Upload to Private Cold Storage (Zero Public Access) ───
echo "☁️ Uploading encrypted backup to private cold storage (${STORAGE_BUCKET})..."
if command -v aws &>/dev/null; then
  aws s3 cp "${ENCRYPTED_DUMP}" "${STORAGE_BUCKET}/" --acl private --sse AES256
  aws s3 cp "${CHECKSUM_FILE}" "${STORAGE_BUCKET}/" --acl private
  echo "✅ Uploaded via AWS CLI."
elif command -v s3cmd &>/dev/null; then
  s3cmd put "${ENCRYPTED_DUMP}" "${STORAGE_BUCKET}/" --acl-private
  s3cmd put "${CHECKSUM_FILE}" "${STORAGE_BUCKET}/" --acl-private
  echo "✅ Uploaded via s3cmd."
else
  echo "ℹ️ Cloud CLI (aws/s3cmd) not found in PATH. Backup remains securely encrypted in local vault: ${ENCRYPTED_DUMP}"
fi

# ─── 6. Local Rotation & Cleanup ───
echo "🧹 Pruning local encrypted backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -type f -name "zanko_db_*.enc" -mtime +"${RETENTION_DAYS}" -delete
find "${BACKUP_DIR}" -type f -name "zanko_db_*.sha256" -mtime +"${RETENTION_DAYS}" -delete

echo "=========================================================="
echo "🎉 ZankoAI Database Backup Process Completed Successfully!"
echo "• Archive: ${ENCRYPTED_DUMP}"
echo "• Checksum: ${CHECKSUM}"
echo "=========================================================="
