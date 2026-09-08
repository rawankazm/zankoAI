# ZankoAI Production Database Backup & Disaster Recovery Runbook

This document defines the production backup architecture, encryption standards, retention policies, restore testing procedures, and disaster recovery runbooks for the **ZankoAI Supabase PostgreSQL** database.

---

## 1. Backup Strategy & Frequency Matrix

| Backup Type | Frequency | Tool / Mechanism | Storage Target | Encryption | Retention |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Continuous WAL (PITR)** | Continuous (every transaction) | Supabase Continuous WAL Archiving | Supabase Dedicated Storage | KMS Managed AES-256 | **7 Days** |
| **Full Logical Snapshot** | **Every 6 Hours** (00:00, 06:00, 12:00, 18:00 UTC) | `deploy/backup_database.sh` (`pg_dump` + gzip) | Private Cloud Bucket (DO Spaces / S3) | **Client-side AES-256-CBC** (PBKDF2) | **30 Days** |
| **Weekly Cold Archive** | Every Sunday at 02:00 UTC | Automated GFS Rotation | Cold Storage Vault | Client-side AES-256-CBC | **12 Weeks** |
| **Pre-Migration Snapshot** | Before every production schema migration | Manual / CI pipeline hook | Private Bucket | Client-side AES-256-CBC | **14 Days** |

---

## 2. Backup Protection & Zero-Public Storage Policy

To eliminate data leakage risks, all ZankoAI backups are governed by strict security policies:

1. **Zero Public Access**:
   - Cloud storage buckets (e.g. `s3://zanko-production-vault/db-backups`) have **Block Public Access** permanently enabled with strict IAM bucket policies.
   - ACL is explicitly set to `private`. Direct URL downloads without signed IAM credentials return HTTP 403 Forbidden.
2. **Client-Side Symmetric Encryption (AES-256-CBC)**:
   - Backups are encrypted with OpenSSL AES-256-CBC using PBKDF2 key derivation (`-salt -iter 100000`) before leaving the server.
   - Even in the event of a cloud storage breach, raw database rows, user emails, passwords hashes, and payment tokens remain mathematically undecryptable without `BACKUP_ENCRYPTION_KEY`.
3. **Cryptographic Integrity & Tamper-Evidence (SHA-256)**:
   - For every backup `zanko_db_<timestamp>.sql.gz.enc`, a companion `zanko_db_<timestamp>.sha256` hash is generated.
   - Restoration scripts verify the checksum prior to decryption, immediately aborting if any bit has corrupted or been altered.
4. **Credential Isolation**:
   - `BACKUP_ENCRYPTION_KEY` is injected via environment variable at runtime from a secure secret store. It is never checked into Git or stored in public config files.

---

## 3. Retention & Pruning Policy (Grandfather-Father-Son)

Backups are rotated automatically using the GFS scheme to balance recovery depth with storage efficiency:
- **Daily Backups**: Retained for **30 days**.
- **Weekly Backups**: Retained for **12 weeks** (3 months).
- **Monthly Backups**: Retained for **1 year** in compressed cold storage.
- Local temporary files in `/var/backups/zanko_db` are pruned automatically by `backup_database.sh` using `find -mtime +30 -delete`.

---

## 4. Disaster Recovery (DR) Runbooks

### Runbook A: Full Primary Database Outage / Catastrophic Corruption
*Condition: Total database loss, hardware node corruption, or unrecoverable table drops.*

#### Option 1: Point-in-Time Recovery (PITR) via Supabase Console
*(Preferred if downtime is under 7 days and Supabase control plane is operational)*
1. Log into the **Supabase Dashboard** -> Project Settings -> Database -> Backups.
2. Under **Point-in-Time Recovery**, select the exact minute prior to the failure (e.g., `2026-09-08 14:15:00 UTC`).
3. Click **Restore Database**. Supabase spins up a new cluster from the base backup and replays WAL transactions up to that exact timestamp.
4. Update `DATABASE_URL` in `/var/www/zankoAI/backend/.env.production` if the connection string changed.
5. Restart backend services:
   ```bash
   docker compose -f backend/docker-compose.prod.yml restart api worker
   ```

#### Option 2: Cold Disaster Restoration from Encrypted Offsite Dump
*(Used if Supabase project is lost or migrating to an alternate cloud PostgreSQL instance)*
1. Provision a new PostgreSQL 16+ instance (Supabase or AWS RDS / DigitalOcean Managed DB).
2. Download the latest encrypted backup and matching checksum:
   ```bash
   aws s3 cp s3://zanko-production-vault/db-backups/zanko_db_latest.sql.gz.enc ./
   aws s3 cp s3://zanko-production-vault/db-backups/zanko_db_latest.sha256 ./
   ```
3. Run the automated restore utility:
   ```bash
   export BACKUP_ENCRYPTION_KEY="your-vault-key"
   ./deploy/restore_database.sh zanko_db_latest.sql.gz.enc "postgresql://postgres:password@new-db-host:5432/postgres"
   ```
4. Update `.env.production` with the new database URL and verify health probe:
   ```bash
   curl -f http://localhost:4000/api/ready
   ```

---

### Runbook B: Accidental Table Deletion or Row Corruption
*Condition: A developer or rogue query accidentally deleted rows (e.g. `DELETE FROM users` or dropped a table) without affecting the rest of the database.*

**Goal: Recover the missing rows WITHOUT wiping transactions created since the incident!**

1. Create a local scratch database or isolated schema on the staging server:
   ```sql
   CREATE SCHEMA zanko_recovery_scratch;
   ```
2. Restore the encrypted backup into the recovery schema:
   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in zanko_db_latest.sql.gz.enc -pass "pass:$BACKUP_ENCRYPTION_KEY" \
     | gzip -d \
     | sed 's/public\./zanko_recovery_scratch\./g' \
     | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SET search_path TO zanko_recovery_scratch;" -f -
   ```
3. Surgically extract and restore only the deleted rows using `ON CONFLICT DO NOTHING`:
   ```sql
   -- Example: Surgically restore deleted users
   INSERT INTO public.users (id, email, name, role, university_id, college_id, is_vip, created_at, updated_at)
   SELECT id, email, name, role, university_id, college_id, is_vip, created_at, updated_at
   FROM zanko_recovery_scratch.users
   ON CONFLICT (id) DO NOTHING;

   -- Example: Surgically restore deleted subscriptions
   INSERT INTO public.subscriptions (id, user_id, plan_id, status, current_period_start, current_period_end, created_at)
   SELECT id, user_id, plan_id, status, current_period_start, current_period_end, created_at
   FROM zanko_recovery_scratch.subscriptions
   ON CONFLICT (id) DO NOTHING;
   ```
4. Clean up the temporary schema:
   ```sql
   DROP SCHEMA zanko_recovery_scratch CASCADE;
   ```

---

## 5. Routine Monthly Restore Testing Drill

To comply with the requirement *"Do not claim backup protection without actually testing restoration"*, the engineering team conducts monthly restore drills using [`deploy/verify_restore.sh`](file:///c:/dev/zankoAI/deploy/verify_restore.sh):

```bash
export BACKUP_ENCRYPTION_KEY="your-vault-key"
export DATABASE_URL="postgresql://postgres:pass@localhost:5432/zanko"
./deploy/verify_restore.sh /var/backups/zanko_db/zanko_db_latest.sql.gz.enc
```

### The 9 Mandatory Restoration Checkpoints:
1. **Backup Exists**: Confirms file is on disk and has non-zero byte size.
2. **Backup is Restorable**: Verifies AES-256 decryption and gzip stream integrity.
3. **Restore to Isolated Environment**: Injects into a standalone sandbox schema (`zanko_restore_sandbox_<timestamp>`) without touching live production tables.
4. **Verify Important Tables**: Validates schema presence for `users`, `subscriptions`, `payment_transactions`, `courses`, `ai_conversations`, `ai_messages`, `documents`.
5. **Verify User Data**: Validates student, teacher, and admin profile records, universities, and VIP statuses.
6. **Verify Subscriptions**: Validates subscription records, plan durations, and grace period timestamps.
7. **Verify Payments**: Validates payment records, FIB / ZainCash transaction IDs, amounts, and statuses.
8. **Verify Courses**: Validates curriculum structure, stages, semesters, and course syllabus data.
9. **Verify AI Data**: Validates AI chat sessions, message histories, and processed document vector metadata.
