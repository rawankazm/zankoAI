# ZankoAI Production Rollback Strategy

This runbook describes the exact procedures for rolling back bad releases across ZankoAI infrastructure: DigitalOcean API Backend, Workers, Supabase Database, Admin Panel, and Flutter Client.

---

## 1. Pre-Rollback Assessment Checklist

Before triggering a rollback, the Incident Commander must verify:
- [ ] Is the issue caused by recent deployment (within the last 2 hours)?
- [ ] Is fixing forward impossible within 15 minutes?
- [ ] Have active error logs and telemetry been captured for offline post-mortem?
- [ ] Will rollback cause database schema incompatibility or data loss?

---

## 2. DigitalOcean API Backend Rollback

### Scenario A: Docker Container / App Platform Deployment
1. **Identify Previous Working Image Digest**:
   ```bash
   # List recent images in registry
   doctl registry repository list-tags zanko-backend
   ```
2. **Rollback to Previous Tag**:
   ```bash
   # If using App Platform
   doctl apps create-deployment <APP_ID> --rollback

   # If using Docker Compose on Droplet
   export PREVIOUS_TAG=v1.4.2
   docker pull registry.digitalocean.com/zanko/backend:$PREVIOUS_TAG
   docker tag registry.digitalocean.com/zanko/backend:$PREVIOUS_TAG zanko-backend:current
   docker compose up -d --no-deps api
   ```
3. **Verify Health & Readiness**:
   ```bash
   curl -i http://localhost:4000/api/health
   curl -i http://localhost:4000/api/ready
   ```

### Scenario B: Bare-Metal / PM2 Deployment on Droplet
1. **Rollback Git Repository to Previous Release Tag**:
   ```bash
   cd /var/www/zankoAI/backend
   git fetch --tags
   git checkout tags/v1.4.2
   npm install --production
   npm run build
   ```
2. **Reload Zero-Downtime Cluster via PM2**:
   ```bash
   pm2 reload zanko-api --update-env
   ```
3. **Verify Logs**:
   ```bash
   pm2 logs zanko-api --lines 50
   ```

---

## 3. Database Migration Rollback (Supabase PostgreSQL)

ZankoAI follows the **Expand and Contract** pattern for database changes to ensure backward compatibility across releases.

### Safe Rollback Principles:
- Never drop columns in the same release that stops using them.
- New columns must always be nullable or provide safe defaults.
- Indexes should be created with `CONCURRENTLY`.

### Executing Down-Migration:
1. **Identify Target Migration**:
   ```bash
   supabase migration list
   ```
2. **Revert Migration**:
   If a migration introduced breaking constraints or functions:
   ```sql
   -- Example: Reverting bad index or policy
   DROP INDEX CONCURRENTLY IF EXISTS idx_problematic_query;
   DROP POLICY IF EXISTS "policy_causing_lockups" ON public.subscriptions;
   ```
3. **Apply Compensating Migration**:
   Always prefer applying a new forward migration with the revert rather than rewriting migration history in production:
   ```bash
   supabase migration new revert_broken_policy
   # Add DROP / ALTER statements, then:
   supabase db push
   ```

---

## 4. BullMQ Queue & Worker Rollback

When a worker bug causes jobs to fail or enter dead-letter state:

1. **Pause Ingestion & Workers**:
   ```bash
   # Pause queue via CLI or Redis command
   redis-cli -u $REDIS_URL eval "return redis.call('hset', 'bull:pdf:meta', 'paused', 1)" 0
   ```
2. **Rollback Worker Container**:
   ```bash
   docker compose up -d --no-deps worker-pdf worker-ocr worker-ai
   ```
3. **Re-queue Failed Jobs from Dead-Letter**:
   Once the worker is rolled back to a stable release, drain or retry dead-letter jobs:
   ```bash
   # Use Unified Queue management script or BullMQ dashboard
   npm run queue:retry-failed
   ```
4. **Resume Processing**:
   ```bash
   redis-cli -u $REDIS_URL eval "return redis.call('hdel', 'bull:pdf:meta', 'paused')" 0
   ```

---

## 5. Web Admin Panel Rollback (Vercel)

1. Open Vercel Dashboard at `https://vercel.com/` for project `zanko-admin`.
2. Navigate to **Deployments**.
3. Locate the previous production deployment (tagged `Ready`).
4. Click the three dots `...` -> **Promote to Production** (Instant rollback within 5 seconds).

---

## 6. Mobile Client Mitigation (Flutter Android & iOS)

Because App Store and Google Play deployments cannot be instantly rolled back:

1. **Emergency Maintenance Banner**:
   Activate remote feature flag via Supabase / Firebase Remote Config:
   ```json
   {
     "maintenance_mode": true,
     "min_supported_version": "1.4.0",
     "announcement_message_ku": "سیستم لە ژێر چاکسازییەکی خێرادایە، تکایە کەمێکی تر تاقی بکەرەوە."
   }
   ```
2. **Force-Update Deprecated Versions**:
   Bump `min_supported_version` to force users to upgrade if a critical client vulnerability exists.

---

## 7. Post-Rollback Validation Steps

Execute the production validation script:
```bash
# 1. Check Liveness Probe (Expect HTTP 200)
curl -f -s http://localhost:4000/api/health | jq .

# 2. Check Readiness Probe (Expect HTTP 200 with DB, Redis, Disk ok)
curl -f -s http://localhost:4000/api/ready | jq .

# 3. Check Overall Metrics & Alert State (Expect status: healthy)
curl -f -s http://localhost:4000/api/metrics | jq .status
```
