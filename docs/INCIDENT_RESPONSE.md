# ZankoAI Production Incident Response Runbook

This document defines the production incident response protocol for **ZankoAI**, including alert thresholds, triage workflows, escalation paths, and post-incident reviews.

---

## 1. Incident Classification Matrix

| Severity | Definition | Examples | SLA (Ack / Resolve) |
| :--- | :--- | :--- | :--- |
| **SEV-1 (Critical)** | Core service completely unavailable or data loss imminent. Massive customer impact. | • API down or crashing continuously (`/api/health` 500)<br>• Supabase DB unreachable<br>• Redis cluster down<br>• Zero successful AI completions | **15 mins / 1 hour** |
| **SEV-2 (Major)** | Major functionality impaired; workarounds unavailable or partial system outage. | • p95 API Latency > 3000ms<br>• 5xx Error Rate > 5%<br>• Payment Gateway (FIB / ZainCash) failing<br>• OCR / PDF queues backed up (> 500 jobs) | **30 mins / 4 hours** |
| **SEV-3 (Moderate)** | Non-critical feature degraded; business operations can continue. | • Audio lecture transcription delay<br>• Push notification delivery delayed<br>• Memory usage warning (> 85%)<br>• Non-blocking webhook failure | **2 hours / 24 hours** |
| **SEV-4 (Minor)** | Cosmetic bug, intermittent UI glitch, or minor log anomalies. | • Slow admin analytics query<br>• Missing minor telemetry event<br>• Minor frontend layout flaw | **Next Business Day** |

---

## 2. On-Call Roles & Communication

1. **Incident Commander (IC)**:
   - Owns decision making, incident log, customer communications, and rollback authorization.
2. **Lead Technical Responder**:
   - Diagnoses logs, isolates root cause, applies code fixes, restarts services, or initiates rollback.
3. **Communication Channels**:
   - **Internal War Room**: Discord / Slack `#incident-war-room`
   - **Internal Audio Call**: Google Meet or Telegram voice bridge
   - **Status Updates**: Internal dashboard & external customer broadcast banner via Remote Config

---

## 3. Automated Alert Triggers & Evaluation

Production monitoring queries `GET /api/metrics` every 30 seconds. Alerts are raised based on the following configured thresholds:

```json
{
  "cpu_critical": 90,
  "ram_critical": 92,
  "disk_critical": 95,
  "http_5xx_rate_critical": 5.0,
  "latency_p95_critical_ms": 3000,
  "queue_length_critical": 500,
  "failed_jobs_critical": 50,
  "payment_errors_critical": 5
}
```

### Alert Response Procedures

#### A. Database Outage (`database.status == "down"`)
1. Check Supabase Status dashboard (`https://status.supabase.com/`).
2. Verify egress connectivity from DigitalOcean to Supabase connection pooler (`port 6543 / 5432`).
3. Check PostgreSQL connection pool exhaustion:
   ```bash
   # On droplet / server
   curl -s http://localhost:4000/api/ready | jq .
   ```
4. If connections exhausted, restart backend to flush lingering socket pools, or increase pool size in Supabase.

#### B. Redis Failure (`redis.status == "down"`)
1. Check Redis container / systemd service:
   ```bash
   systemctl status redis || docker ps | grep redis
   ```
2. Verify Redis RAM consumption:
   ```bash
   redis-cli info memory
   ```
3. If Redis crashed due to OOM, restart with increased memory limit or adjust `maxmemory-policy allkeys-lru`.

#### C. API Latency Spike (p95 > 3000ms) or 5xx Rate > 5%
1. Inspect structured JSON access logs with `request_id`:
   ```bash
   docker logs --tail 200 zanko-backend | jq 'select(.status >= 500)'
   ```
2. Identify slow routes via `duration_ms` in structured logs.
3. If AI upstream (Gemini / OpenAI) is hanging, verify timeouts (`30s`) in `ai.service.ts` are aborting cleanly.
4. Scale container replicas or restart worker processes.

#### D. Worker & Queue Congestion (`queue_length > 500` or `failed_jobs > 50`)
1. Inspect queue health:
   ```bash
   curl -s http://localhost:4000/api/health/worker | jq .
   ```
2. Check BullMQ dead-letter jobs:
   ```bash
   curl -s http://localhost:4000/api/metrics | jq .metrics.workers
   ```
3. Restart stuck workers or scale worker concurrency:
   ```bash
   docker restart zanko-worker
   ```

#### E. Payment Gateway Outage (`paymentErrors > 5`)
1. Check FIB / ZainCash API status and network latency.
2. Verify IP whitelisting on payment gateway merchant portal.
3. If gateway is down, activate system grace period: users retain premium access without disruption until gateway recovers.

---

## 4. Sensitive Data Masking Verification

In all incident logs, confirm zero sensitive data is printed:
- **Never log**: Passwords, auth tokens, Supabase service keys, AI keys, full card numbers, CVV.
- All JSON logs MUST have keys matched by `SENSITIVE_KEY_REGEX` redacted as `"[REDACTED]"`.
- All Bearer headers and AI API keys (`AIzaSy...`, `sk-...`) must appear masked.

---

## 5. Post-Incident Review (PIR) Process

Within 24 hours of resolving a SEV-1 or SEV-2 incident, conduct a blameless post-mortem:
1. **Summary**: Timeline from alert trigger to mitigation.
2. **Impact**: User count affected, failed requests, revenue impacted.
3. **Root Cause**: 5-Whys root cause analysis.
4. **Action Items**: Preventative bugs, alerts added, code guardrails updated.
