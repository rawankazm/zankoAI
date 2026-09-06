# ZankoAI Supabase Cost Control & Monthly Active User (MAU) Guide

This document defines the architectural guidelines, cost-control mechanisms, and operational runbooks for managing Supabase infrastructure at scale for **ZankoAI**.

---

## 1. Core Principle: Registered Users vs. Monthly Active Users (MAU)

It is critical to distinguish between these two metrics to understand infrastructure capacity and avoid cost miscalculations:

| Metric | Definition | Impact on Supabase Billing |
| :--- | :--- | :--- |
| **Total Registered Users** | Total accounts ever created in `auth.users` / `profiles`. | **$0 extra cost.** Supabase does **not** charge for dormant or inactive user records in PostgreSQL (only negligible disk space). |
| **Daily Active Users (DAU)** | Unique users who authenticate or interact with the platform on a specific UTC day. | Operational metric for peak concurrency and database load. |
| **Monthly Active Users (MAU)** | **Unique users** who actively authenticate, refresh an auth token, or make authenticated API calls within a rolling 30-day window or calendar month. | **Directly drives billing tier and quotas.** Extra active users beyond plan quotas incur overage charges. |

### Zero Double-Counting Guarantee
In ZankoAI, activity is tracked via `user_daily_activity` with a composite primary key:
```sql
PRIMARY KEY (user_id, activity_date)
```
- A user logging in 100 times in a single day produces **only 1 row**.
- A user active on 25 different days of the month is counted as **exactly 1 MAU** when computing monthly distinct aggregates:
```sql
SELECT COUNT(DISTINCT user_id) 
FROM user_daily_activity 
WHERE activity_date >= DATE_TRUNC('month', CURRENT_DATE);
```

---

## 2. Supabase Tier Quotas & Cost Reference

| Resource | Free Tier Limit | Pro Tier ($25/mo) Limit | Additional Cost Beyond Quota |
| :--- | :--- | :--- | :--- |
| **Monthly Active Users (MAU)** | 50,000 MAU | 100,000 MAU included | **$0.00325 per additional MAU** |
| **Database Size** | 500 MB | 8 GB disk included | $0.125 per additional GB/month |
| **File Storage** | 1 GB | 100 GB included | $0.021 per additional GB/month |
| **Monthly Egress (Bandwidth)** | 2 GB | 250 GB included | $0.09 per additional GB |
| **Realtime Peak Connections** | 200 concurrent | 500 concurrent included | $10 per 1,000 additional connections |
| **Edge Function Invocations** | 500,000 calls | 2,000,000 calls included | $2.00 per 1,000,000 calls |

---

## 3. Strict Rule: Never Auto-Upgrade Plans

> [!CAUTION]
> **No Automatic Tier Upgrades**:
> ZankoAI system policy prohibits automatic self-upgrades to higher Supabase billing tiers. Auto-upgrades can trigger runaway spending if abnormal traffic spikes or DDoS attempts occur.
> Instead, the system triggers **multi-level alerts** to the administrative team to decide on deliberate scaling actions.

### Configurable Alert Threshold Matrix

Alerts are stored in the database (`supabase_cost_thresholds`) and evaluated automatically:

| Metric | Threshold Value | Severity | Alert Action |
| :--- | :--- | :--- | :--- |
| **MAU** | **50,000 MAU** | `info` | Free Tier ceiling reached. Plan upgrade to Pro ($25/mo) recommended. |
| **MAU** | **75,000 MAU** | `warning` | 75% of Pro Tier included capacity reached. |
| **MAU** | **90,000 MAU** | `warning` | 90% of Pro Tier capacity reached. Prepare budget for overage. |
| **MAU** | **100,000 MAU** | `critical` | Pro Tier included MAU exhausted. Next users will incur $0.00325/MAU. |
| **Database Size** | **400 MB** | `warning` | 80% of Free Tier 500 MB reached. Run vacuum and prune audit logs. |
| **Database Size** | **7,000 MB (7 GB)** | `warning` | 87% of Pro Tier 8 GB reached. |
| **Storage** | **800 MB** | `warning` | 80% of Free Tier 1 GB reached. Trigger orphaned file cleaner. |
| **Storage** | **80 GB** | `warning` | 80% of Pro Tier 100 GB reached. |
| **Egress** | **1.8 GB** | `warning` | 90% of Free Tier 2 GB bandwidth reached. |
| **Egress** | **200 GB** | `warning` | 80% of Pro Tier 250 GB bandwidth reached. |

---

## 4. Five Pillars of Supabase Cost Optimization

### 1. Database Size Management
- **90-Day Retention Pruning**: Raw daily activity logs in `user_daily_activity` are pruned after 90 days (`MauAggregationJob`). Their aggregated totals remain permanently in `monthly_active_users` and `daily_active_users`.
- **Row-Level Security (RLS) Optimization**: All RLS policies use indexed joins (e.g. `idx_profiles_role`, `idx_courses_department`) to prevent full-table sequential scans.
- **Auto-Vacuuming**: Run regular `VACUUM ANALYZE` on high-churn tables (`user_daily_activity`, `usage_records`).

### 2. File Storage Management
- **Image Optimization**: All profile avatars and exam photo uploads are converted to WebP format before being uploaded to Supabase Storage.
- **Orphaned File Cleaner**: The background job `StorageService.cleanupOrphanedFiles(olderThanHours = 24)` scans storage buckets for unreferenced temporary uploads and removes them daily.

### 3. Egress (Bandwidth) Control
- **DigitalOcean API Gateway Caching**: Static resources, syllabus data, and public course catalogs are cached at our Node.js gateway and Redis layer with HTTP `Cache-Control: public, max-age=3600` headers.
- **Supabase Storage Direct Downloads**: Signed URLs are generated with short lifespans (15 minutes) to prevent bandwidth leeching.

### 4. Realtime Connection Optimization
- **Disconnect on Background**: The Flutter mobile application automatically unsubscribes from Supabase Realtime channels when the app is minimized or pushed to the background (`AppLifecycleState.paused`).
- **Targeted Channels**: Do not broadcast entire table changes. Use filtered row-level channels:
  ```dart
  supabase.channel('user_${user.id}').onPostgresChanges(...);
  ```

### 5. API Zero-DB Latency Path
- Authenticated requests pass through `ActivityTrackerService` with a Redis O(1) deduplication check (`SET mau:active:YYYY-MM-DD:userId 1 EX 172800 NX`).
- If a user has already made an API call today, **0 database queries** are made for activity tracking.

---

## 5. Admin Dashboard API Endpoints

### 1. Get User & MAU Analytics
```http
GET /api/admin/analytics/users
Authorization: Bearer <ADMIN_JWT_TOKEN>
```

**Response (HTTP 200)**:
```json
{
  "success": true,
  "message": "User analytics retrieved successfully",
  "data": {
    "total_registered_users": 15420,
    "daily_active_users": 1280,
    "monthly_active_users": 8940,
    "new_users": 65,
    "new_users_this_month": 420,
    "active_students": 8430,
    "active_teachers": 510,
    "premium_users": 1320,
    "free_users": 7620,
    "period": "2026-09",
    "alerts": [],
    "generated_at": "2026-09-06T20:30:00.000Z"
  }
}
```

### 2. View Active Cost & Scale Alerts
```http
GET /api/admin/analytics/alerts?unacknowledged=true
Authorization: Bearer <ADMIN_JWT_TOKEN>
```

### 3. Acknowledge and Dismiss an Alert
```http
POST /api/admin/analytics/alerts/:id/acknowledge
Authorization: Bearer <ADMIN_JWT_TOKEN>
```

### 4. Update a Threshold Configuration
```http
PUT /api/admin/analytics/thresholds/:id
Authorization: Bearer <ADMIN_JWT_TOKEN>
Content-Type: application/json

{
  "threshold_value": 85000,
  "severity": "warning",
  "description": "Adjusted alert for 85k MAU"
}
```

---

## 6. Emergency Runbook: When 100,000 MAU Alert Fires

When the **100,000 MAU** critical alert triggers:

1. **Verify Authenticity**:
   - Inspect `GET /api/admin/analytics/users` to verify whether the spike is organic (e.g. university exam period) or bot traffic.
   - Check `new_users` vs active returning users.
2. **Review Supabase Cost Impact**:
   - Every additional 1,000 MAU above 100k costs **$3.25/month**.
   - If projected MAU reaches 150,000, expected overage is:
     $$ (150,000 - 100,000) \times \$0.00325 = \$162.50/\text{month} $$
3. **Assess VIP Revenue**:
   - Check `premium_users` count. If 1,000 users are on VIP plans ($3 - $5/mo each), monthly platform revenue is $3,000 - $5,000, which easily covers the $162 overage cost.
4. **Tune Redis Session Lifespans**:
   - If costs need to be constrained immediately, extend client session token refresh intervals from 1 hour to 12 hours to reduce authentication frequency.
