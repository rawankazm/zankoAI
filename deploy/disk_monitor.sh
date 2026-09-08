#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Disk Space Monitoring Utility
# ==============================================================================

set -euo pipefail

THRESHOLD=${DISK_THRESHOLD:-85}
USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[${TIMESTAMP}] Checking disk utilization on root filesystem..."
echo "Current Usage: ${USAGE}% | Alert Threshold: ${THRESHOLD}%"

if [ "${USAGE}" -ge "${THRESHOLD}" ]; then
  ALERT_MSG="🚨 [CRITICAL ALERT] Root disk space has reached ${USAGE}% (Threshold: ${THRESHOLD}%) on $(hostname) at ${TIMESTAMP}"
  echo "${ALERT_MSG}" >&2
  logger -t "ZANKO_DISK_ALERT" -p user.crit "${ALERT_MSG}"
  echo "${ALERT_MSG}" >> /var/log/zanko_disk_alerts.log 2>/dev/null || true

  echo "🧹 Running automatic Docker reclamation to prevent disk exhaustion..."
  docker image prune -af --filter "until=168h" || true
  docker container prune -f || true
  docker volume prune -f || true
  
  NEW_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
  echo "Post-cleanup disk usage: ${NEW_USAGE}%"
  exit 1
else
  echo "✅ Disk space is healthy (${USAGE}% used)."
  exit 0
fi
