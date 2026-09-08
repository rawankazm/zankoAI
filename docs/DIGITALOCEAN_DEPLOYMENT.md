# ZankoAI DigitalOcean Production Deployment Guide

This guide details the end-to-end production deployment of **ZankoAI** on a dedicated DigitalOcean Droplet running **Ubuntu LTS**, **Docker**, **Docker Compose**, and **Nginx** reverse proxy under domain `api.zankoai.com`.

---

## 1. System Architecture & Port Security

```
[ Internet ]
      │
   HTTPS (Port 443) / HTTP (Port 80 -> 301 Redirect)
      ▼
[ UFW Firewall: Only 22, 80, 443 Allowed ]
      │
      ▼
[ Nginx Reverse Proxy (Container: zanko_nginx) ]
      │ (Docker Internal Bridge: zanko_network)
      ├──► [ Node.js API (zanko_api:4000) ] ────► [ Supabase PostgreSQL / AI APIs ]
      │             │
      │             ▼
      └──► [ BullMQ Worker (zanko_worker) ] ───► [ Redis (zanko_redis:6379) ]
```

### 🔒 Zero Public Exposure Guarantee:
- **Port 4000 (Node.js API)** is **NOT** mapped to the host (`0.0.0.0:4000`). It is strictly private on the internal Docker network.
- **Port 6379 (Redis)** is **NOT** mapped to the host (`0.0.0.0:6379`). It is protected with a 64-character password and accessible only to `api` and `worker` containers.
- **Worker Container** has no public ports and only connects internally to Redis and Supabase.
- **UFW Firewall** strictly rejects all incoming traffic except ports `22` (SSH), `80` (HTTP), and `443` (HTTPS).

---

## 2. Droplet Specifications & Recommendations

| Parameter | Recommended Spec | Minimum Spec |
| :--- | :--- | :--- |
| **OS** | Ubuntu 24.04 LTS (x64) | Ubuntu 22.04 LTS (x64) |
| **Compute** | 2 vCPUs (General Purpose or Basic Dedicated) | 1 vCPU |
| **RAM** | 4 GB | 2 GB (+ 2GB Swap) |
| **SSD** | 50 GB NVMe | 25 GB SSD |
| **Region** | Frankfurt (FRA1) or Amsterdam (AMS3) | Closest to Iraqi / Middle East traffic |

---

## 3. Step-by-Step Deployment Instructions

### Step 1: Configure Domain DNS
Before configuring SSL certificates, configure an **A Record** on your DNS provider (Cloudflare, Namecheap, or DigitalOcean DNS):
```
Type: A
Name: api
Value: <YOUR_DROPLET_PUBLIC_IPV4>
TTL: Auto / 300s
Proxy: DNS Only (Grey Cloud if using Cloudflare during initial cert issuance)
```

### Step 2: Connect to Droplet & Clone Repository
SSH into your fresh Droplet as `root`:
```bash
ssh root@<YOUR_DROPLET_IP>
```

Clone the ZankoAI codebase:
```bash
mkdir -p /var/www
git clone https://github.com/rawankazm/zankoAI.git /var/www/zankoAI
cd /var/www/zankoAI
```

### Step 3: Run Automated Server Hardening
Execute the provisioning script:
```bash
chmod +x deploy/setup_server.sh
./deploy/setup_server.sh
```

**What this script configures automatically:**
1. Creates dedicated non-root user `zanko_deploy` with `sudo` and `docker` privileges.
2. Copies root SSH authorized keys to `zanko_deploy`.
3. Disables password authentication and locks down SSH.
4. Enables UFW firewall allowing ONLY ports `22`, `80`, and `443`.
5. Enables `unattended-upgrades` for automatic Ubuntu security updates.
6. Installs official Docker Engine and Docker Compose plugin.
7. Sets up Docker log rotation (`max-size: 50m`, `max-file: 5`) to prevent disk exhaustion.
8. Installs hourly disk monitoring cron job triggering alerts if disk exceeds `85%`.
9. Installs `certbot` for Let's Encrypt certificates.

### Step 4: Issue Let's Encrypt SSL Certificate
Run Certbot in standalone webroot mode for `api.zankoai.com`:
```bash
certbot certonly --webroot \
  -w /var/www/certbot \
  -d api.zankoai.com \
  --email admin@zankoai.com \
  --agree-tos \
  --no-eff-email
```

Certificates will be installed at:
- `/etc/letsencrypt/live/api.zankoai.com/fullchain.pem`
- `/etc/letsencrypt/live/api.zankoai.com/privkey.pem`

*(Note: Automated certificate renewal is handled via systemd timer `certbot.timer`).*

### Step 5: Configure Production Secrets (.env.production)
Switch to the deployment user:
```bash
su - zanko_deploy
cd /var/www/zankoAI/backend
cp .env.production.example .env.production
nano .env.production
```

Set the production variables:
```bash
NODE_ENV=production
PORT=4000
CORS_ORIGIN=https://zanko-admin.vercel.app,https://zankoai.com,https://www.zankoai.com

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_JWT_SECRET=...

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=YOUR_STRONG_RANDOM_REDIS_PASSWORD

# AI Models & Keys
DEFAULT_AI_PROVIDER=google
GEMINI_API_KEY=...
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=...
```

### Step 6: Deploy Services
Run the automated zero-downtime deployment script:
```bash
cd /var/www/zankoAI
chmod +x deploy/deploy.sh
./deploy/deploy.sh
```

This script will:
1. Build `zanko_api` and `zanko_worker` containers.
2. Launch `zanko_redis`, `zanko_api`, `zanko_worker`, and `zanko_nginx`.
3. Wait for all containers to pass their internal healthchecks.
4. Test live local endpoints.
5. Prune dangling Docker images.

---

## 4. Production Verification & Testing Runbook

Execute the automated deployment verification test suite:
```bash
chmod +x deploy/test_deployment.sh
./deploy/test_deployment.sh
```

### Manual Verification Checks:

#### 1. Test Server Reboot Recovery
Verify that all containers and services automatically come back up after a full Droplet reboot:
```bash
sudo reboot
```
Wait 45 seconds, then reconnect and run:
```bash
docker ps
```
*Expected Result:* All 4 containers (`zanko_nginx`, `zanko_api`, `zanko_worker`, `zanko_redis`) are in `Up (healthy)` state.

#### 2. Test Docker Restart Policy
Simulate a killed or crashed container:
```bash
docker kill zanko_api
sleep 5
docker ps | grep zanko_api
```
*Expected Result:* Docker restart policy `unless-stopped` immediately resurrects the container to running state.

#### 3. Test Nginx Configuration Syntax
```bash
docker exec zanko_nginx nginx -t
```
*Expected Result:* `syntax is ok` and `test is successful`.

#### 4. Test HTTPS Redirection & Security Headers
```bash
curl -I http://api.zankoai.com/api/health
```
*Expected Result:*
```http
HTTP/1.1 301 Moved Permanently
Location: https://api.zankoai.com/api/health
```

Test HTTPS request:
```bash
curl -I https://api.zankoai.com/api/health
```
*Expected Result:*
```http
HTTP/2 200
strict-transport-security: max-age=63072000; includeSubDomains; preload
x-frame-options: DENY
x-content-type-options: nosniff
x-xss-protection: 1; mode=block
```

#### 5. Test Port Isolation (Negative Security Test)
From your local computer outside DigitalOcean, attempt to connect to internal ports:
```bash
# Test Node.js internal port (Should TIMEOUT / REFUSE)
nc -zv -w 3 <YOUR_DROPLET_IP> 4000

# Test Redis internal port (Should TIMEOUT / REFUSE)
nc -zv -w 3 <YOUR_DROPLET_IP> 6379
```
*Expected Result:* Connection timed out or connection refused. Only ports `22`, `80`, and `443` respond.

---

## 5. Maintenance & Operational Commands

### View Live Logs:
```bash
# Nginx access & error logs (JSON format)
docker logs -f zanko_nginx

# API structured access logs
docker logs -f zanko_api

# Background BullMQ worker logs
docker logs -f zanko_worker
```

### Check Uptime & Resource Metrics:
```bash
curl -s https://api.zankoai.com/api/metrics | jq .
```

### Check Disk Space & Trigger Reclamation:
```bash
/usr/local/bin/zanko_disk_monitor.sh
```
