# ZankoAI Production Deployment Rollback Runbook

This document details the automated and manual rollback strategies for **ZankoAI** production deployments on DigitalOcean.

---

## 1. Rollback Strategy Overview

```
[ Deploy Workflow on 'main' ]
             │
      Deploy to Server
             │
             ▼
    Probe /api/health & /api/ready (60s Window)
             │
      ┌──────┴──────┐
      │             │
    [200 OK]    [Timeout / 5xx Error]
      │             │
   Success       Automated Rollback Triggered
                    │
                    ├──► Revert to previous .env.production.bak
                    ├──► Revert Git HEAD to previous stable commit
                    ├──► Re-execute Docker Compose build & start
                    └──► Validate restored instance health
```

---

## 2. Automated Rollback Flow

If any of the following conditions occur after deployment:
- `/api/health` returns status != 200 or connection refused.
- `/api/ready` reports database or Redis unavailable.
- Container crashes in a crash-loop state.

The GitHub Actions step `Execute Automated Rollback on Health Failure` in `.github/workflows/deploy-production.yml` automatically triggers [`deploy/rollback_deployment.sh`](file:///c:/dev/zankoAI/deploy/rollback_deployment.sh):

```bash
ssh zanko_deploy@$DO_DROPLET_HOST "bash -s" << 'EOF'
  cd /var/www/zankoAI
  chmod +x deploy/rollback_deployment.sh
  ./deploy/rollback_deployment.sh
EOF
```

**Actions taken by the script:**
1. Restores the `.env.production.bak` configuration.
2. Checks out the previous stable git commit (`HEAD~1`).
3. Executes `docker compose -f backend/docker-compose.prod.yml up -d --build --remove-orphans`.
4. Polls `http://localhost/api/health` until HTTP 200 is confirmed.

---

## 3. Manual Emergency Rollback Runbook

If automated rollback cannot connect or an engineer needs to intervene manually:

### Step 1: Connect to the Droplet
```bash
ssh zanko_deploy@<YOUR_DROPLET_IP>
cd /var/www/zankoAI
```

### Step 2: Trigger Rollback Script
```bash
./deploy/rollback_deployment.sh
```

### Step 3: Or Execute Manual Git & Docker Rollback
If you need to rollback to a specific git tag (e.g. `v1.4.2`):
```bash
git fetch --tags
git checkout tags/v1.4.2

# Rebuild containers
cd /var/www/zankoAI/backend
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans
```

### Step 4: Verify Post-Rollback Status
```bash
# Check running containers
docker ps

# Check health endpoint
curl -i https://api.zankoai.com/api/health
curl -i https://api.zankoai.com/api/ready
```

---

## 4. Database Rollback Guidelines (Supabase)

Because application rollbacks must not corrupt database transactions:
- **Zero-Downtime Migration Principle**: All migrations must be backward-compatible (the *Expand-Contract* pattern).
- If a bad migration added a column or index that caused locks:
  - Do NOT rewrite migration history in production.
  - Apply a compensating migration:
    ```sql
    -- Revert faulty index
    DROP INDEX CONCURRENTLY IF EXISTS idx_problematic;
    ```
