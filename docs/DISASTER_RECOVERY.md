# ZankoAI Production Disaster Recovery Runbook

This document defines the Disaster Recovery (DR) procedures for **ZankoAI**, ensuring business continuity, minimal downtime, and zero irreversible data loss in catastrophic failure scenarios.

---

## 1. Disaster Recovery Objectives

| Metric | Target Objective | Description |
| :--- | :--- | :--- |
| **RTO (Recovery Time Objective)** | **< 30 Minutes** | The maximum acceptable duration of system downtime before core services are restored. |
| **RPO (Recovery Point Objective)** | **< 1 Hour** | The maximum acceptable age of data that must be recovered from backup (data loss window). |

---

## 2. Backup & Data Redundancy Architecture

### A. Database (Supabase PostgreSQL)
- **Point-In-Time Recovery (PITR)**: Active with continuous Write-Ahead Log (WAL) archiving up to 7 days.
- **Daily Physical Backups**: Retained for 30 days in separate cloud availability zones.
- **Logical pg_dump Backups**: Exported every 6 hours and encrypted with AES-256 to cold cloud storage.

### B. In-Memory State & Queues (Redis)
- **AOF (Append Only File)**: Configured with `appendfsync everysec` for durable background jobs.
- **RDB Snapshots**: Snapshot triggered every 15 minutes or 1,000 keys changed.

### C. DigitalOcean Compute (Droplet & Volumes)
- **Droplet Snapshots**: Automated weekly snapshots of root filesystem.
- **Persistent Block Storage**: Attached volume for local caches and transient OCR/PDF binaries.

---

## 3. Catastrophic Disaster Scenarios & Recovery Workflows

### Scenario 1: Complete DigitalOcean Droplet Failure
*Condition: Hardware node failure, data center outage, or corrupted host operating system.*

1. **Spin Up New Droplet in Alternate Region (e.g., FRA1 to AMS3)**:
   ```bash
   doctl compute droplet create zanko-backend-recovery \
     --region ams3 \
     --size s-2vcpu-4gb \
     --image ubuntu-24-04-x64 \
     --ssh-keys <YOUR_SSH_KEY_ID>
   ```
2. **Re-attach Floating IP / Update DNS**:
   Point `api.zankoai.com` to the new Droplet IP address via Cloudflare / DigitalOcean DNS.
3. **Provision Container Environment**:
   ```bash
   ssh root@<NEW_DROPLET_IP>
   git clone https://github.com/rawankazm/zankoAI.git /var/www/zankoAI
   cd /var/www/zankoAI/backend
   cp /etc/secrets/.env.production .env
   docker compose -f docker-compose.prod.yml up -d --build
   ```
4. **Validate Restored Instance**:
   ```bash
   curl -f http://localhost:4000/api/health
   curl -f http://localhost:4000/api/ready
   ```

---

### Scenario 2: Catastrophic Database Loss or Table Corruption
*Condition: Accidental table drop, data corruption, or severe logical errors.*

1. **Initiate Supabase Point-in-Time Recovery (PITR)**:
   - Go to **Supabase Dashboard** -> Project Settings -> Database -> Backups.
   - Select **Point in Time Recovery**.
   - Select the exact minute prior to the incident (e.g., `2026-09-08 14:22:00 UTC`).
   - Confirm restoration into a staging project or restore in-place.
2. **Verify Data Integrity**:
   Verify record counts in key operational tables:
   ```sql
   SELECT count(*) FROM public.users;
   SELECT count(*) FROM public.subscriptions;
   SELECT count(*) FROM public.documents;
   ```
3. **Re-point Backend Database URI**:
   If restored to a new database instance, update `DATABASE_URL` in backend `.env` and restart:
   ```bash
   docker compose restart api
   ```

---

### Scenario 3: Redis State Loss or Cold Cluster Restart
*Condition: Redis container died and volume was wiped.*

1. **Restart Redis with Persistence Enabled**:
   ```bash
   docker run -d --name zanko-redis \
     -v redis-data:/data \
     -p 6379:6379 \
     redis:7-alpine redis-server --appendonly yes
   ```
2. **Re-synchronize Background Jobs**:
   Because jobs are logged with status in the `job_metadata` database table:
   - Identify uncompleted jobs with state `queued` or `processing`.
   - Run reconciliation script:
   ```bash
   npm run queue:rehydrate
   ```
3. **Trigger Recurring Schedules**:
   Workers automatically re-register recurring BullMQ jobs on startup.

---

### Scenario 4: Compromised Production Secrets / API Keys
*Condition: Accidental leak of JWT secret, Gemini key, or Supabase service role key.*

1. **Rotate Supabase JWT & Service Role Keys**:
   - Supabase Dashboard -> Project Settings -> API -> Generate new `service_role` key and `anon` key.
2. **Rotate AI Provider Keys**:
   - Google Cloud Console: Create new Gemini API Key; revoke compromised key.
   - OpenAI / Anthropic Console: Revoke compromised keys; generate new production tokens.
3. **Deploy Updated Secrets**:
   Update environment configuration and trigger rolling restart:
   ```bash
   docker compose up -d --force-recreate api worker
   ```
4. **Invalidate Compromised User Sessions**:
   ```sql
   -- Force all users to re-authenticate if auth secret was exposed
   UPDATE auth.users SET updated_at = now();
   ```

---

## 4. Disaster Recovery Validation & Drill Schedule

To guarantee preparedness, the engineering team executes scheduled DR drills:
- **Monthly**: Restore latest database backup into staging and run end-to-end integration tests.
- **Quarterly**: Simulate Droplet failover and DNS switch to secondary standby server.
- **Biannually**: Audit secret rotation procedures and verify zero sensitive data in log archives.
