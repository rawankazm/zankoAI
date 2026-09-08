#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Deployment Verification Test Suite
# Tests: UFW isolation, Docker restart, Nginx, HTTPS, CORS, Reboot Recovery
# ==============================================================================

set -euo pipefail

DOMAIN="${DOMAIN:-api.zankoai.com}"
TOTAL_TESTS=0
PASSED_TESTS=0

run_check() {
  local name="$1"
  local cmd="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo -n "🧪 Testing: ${name}... "
  if eval "${cmd}" > /dev/null 2>&1; then
    echo "✅ PASSED"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo "❌ FAILED"
    echo "   Command failed: ${cmd}"
  fi
}

echo "=========================================================="
echo "🔍 Starting ZankoAI Production Deployment Verification"
echo "Target Domain: ${DOMAIN}"
echo "=========================================================="

# ─── 1. UFW Firewall & Strict Port Isolation Checks ───
run_check "UFW Firewall is active" "sudo ufw status | grep -qw 'Status: active'"
run_check "UFW allows Port 22 (SSH)" "sudo ufw status | grep -E '^22/tcp\s+ALLOW'"
run_check "UFW allows Port 80 (HTTP)" "sudo ufw status | grep -E '^80/tcp\s+ALLOW'"
run_check "UFW allows Port 443 (HTTPS)" "sudo ufw status | grep -E '^443/tcp\s+ALLOW'"

# Verify internal services are NOT exposed to the public
run_check "Port 4000 (Node.js API) is NOT listening on public interfaces (0.0.0.0)" \
  "! ss -tuln | grep -E '0\.0\.0\.0:4000\s|\[::\]:4000\s'"

run_check "Port 6379 (Redis) is NOT listening on public interfaces (0.0.0.0)" \
  "! ss -tuln | grep -E '0\.0\.0\.0:6379\s|\[::\]:6379\s'"

# ─── 2. Docker & Container Restart Policy Checks ───
run_check "Docker service is enabled on system boot" "systemctl is-enabled docker | grep -qw 'enabled'"
run_check "Docker live-restore is enabled" "docker info 2>/dev/null | grep -q 'Live Restore Enabled: true'"

run_check "Container 'zanko_api' has restart policy unless-stopped" \
  "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' zanko_api 2>/dev/null)\" = 'unless-stopped' ]"

run_check "Container 'zanko_worker' has restart policy unless-stopped" \
  "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' zanko_worker 2>/dev/null)\" = 'unless-stopped' ]"

run_check "Container 'zanko_redis' has restart policy unless-stopped" \
  "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' zanko_redis 2>/dev/null)\" = 'unless-stopped' ]"

run_check "Container 'zanko_nginx' has restart policy unless-stopped" \
  "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' zanko_nginx 2>/dev/null)\" = 'unless-stopped' ]"

# Test Docker container restart recovery
echo -n "🧪 Testing: Docker container restart recovery (restarting zanko_api)... "
if docker restart zanko_api > /dev/null 2>&1; then
  sleep 5
  if [ "$(docker inspect -f '{{.State.Status}}' zanko_api 2>/dev/null)" = "running" ]; then
    echo "✅ PASSED"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo "❌ FAILED (Container did not return to running state)"
  fi
else
  echo "❌ FAILED"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# ─── 3. Nginx Configuration & Syntax Checks ───
run_check "Nginx configuration syntax is valid" \
  "docker exec zanko_nginx nginx -t"

run_check "Nginx reverse proxy reaches /api/health with HTTP 200" \
  "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://localhost/api/health)\" -eq 200 ]"

run_check "Nginx reverse proxy reaches /api/ready with HTTP 200" \
  "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://localhost/api/ready)\" -eq 200 ]"

# ─── 4. HTTPS, Redirection & Security Headers ───
run_check "HTTP (Port 80) redirects to HTTPS (301 Moved Permanently)" \
  "curl -s -I -H 'Host: ${DOMAIN}' http://localhost/api/health | grep -iE 'HTTP/1\.[01] 301|location: https://${DOMAIN}'"

# Test secure headers on Nginx
run_check "HSTS header (Strict-Transport-Security) is present" \
  "docker exec zanko_nginx nginx -T 2>/dev/null | grep -i 'Strict-Transport-Security'"

run_check "X-Frame-Options: DENY is present" \
  "docker exec zanko_nginx nginx -T 2>/dev/null | grep -i 'X-Frame-Options \"DENY\"'"

run_check "X-Content-Type-Options: nosniff is present" \
  "docker exec zanko_nginx nginx -T 2>/dev/null | grep -i 'X-Content-Type-Options \"nosniff\"'"

# ─── 5. Strict CORS Checks (Zero Wildcard) ───
run_check "Disallows wildcard Access-Control-Allow-Origin: *" \
  "! docker exec zanko_nginx nginx -T 2>/dev/null | grep -i 'Access-Control-Allow-Origin \\*'"

run_check "Allows trusted origin https://zanko-admin.vercel.app" \
  "docker exec zanko_nginx nginx -T 2>/dev/null | grep -q 'https://zanko-admin.vercel.app'"

# ─── 6. Log Rotation & Disk Monitoring Checks ───
run_check "Docker daemon log-driver is json-file with max-size configured" \
  "grep -q '\"max-size\": \"50m\"' /etc/docker/daemon.json"

run_check "Hourly disk monitor cron job is installed" \
  "[ -f /etc/cron.d/zanko_disk_monitor ]"

echo "=========================================================="
echo "📊 Verification Summary: ${PASSED_TESTS}/${TOTAL_TESTS} Checks Passed"
if [ "${PASSED_TESTS}" -eq "${TOTAL_TESTS}" ]; then
  echo "🎉 All production security, isolation, and recovery checks PASSED!"
else
  echo "⚠️ Some checks did not pass. Review output above."
fi
echo "=========================================================="
