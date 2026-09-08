#!/usr/bin/env bash
# ==============================================================================
# ZankoAI Production Server Provisioning & Hardening Script
# Target OS: Ubuntu 22.04 / 24.04 LTS (DigitalOcean Droplet)
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "🚀 Starting ZankoAI Production Server Setup & Hardening..."
echo "=========================================================="

# Check root privilege
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this setup script as root or with sudo."
  exit 1
fi

DEPLOY_USER="zanko_deploy"
APP_DIR="/var/www/zankoAI"

# ─── 1. System Update & Base Packages ───
echo "📦 Updating APT package repositories..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "📦 Installing essential networking, security, and build tools..."
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ufw \
  fail2ban \
  unattended-upgrades \
  update-notifier-common \
  jq \
  htop \
  git \
  certbot \
  python3-certbot-nginx

# ─── 2. Create Non-Root Deployment User ───
echo "👤 Creating non-root deployment user '${DEPLOY_USER}'..."
if id "${DEPLOY_USER}" &>/dev/null; then
  echo "ℹ️ User '${DEPLOY_USER}' already exists."
else
  useradd -m -s /bin/bash "${DEPLOY_USER}"
  echo "✅ User '${DEPLOY_USER}' created."
fi

# Add user to sudo group
usermod -aG sudo "${DEPLOY_USER}"

# Ensure sudoers config allows smooth deployment operations
cat <<EOF > "/etc/sudoers.d/${DEPLOY_USER}"
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/docker, /usr/bin/docker-compose, /usr/sbin/ufw, /usr/bin/certbot
EOF
chmod 0440 "/etc/sudoers.d/${DEPLOY_USER}"

# Copy root SSH keys to deploy user if present
if [ -d "/root/.ssh" ] && [ -f "/root/.ssh/authorized_keys" ]; then
  echo "🔑 Setting up authorized SSH keys for '${DEPLOY_USER}'..."
  mkdir -p "/home/${DEPLOY_USER}/.ssh"
  cp "/root/.ssh/authorized_keys" "/home/${DEPLOY_USER}/.ssh/authorized_keys"
  chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
  chmod 700 "/home/${DEPLOY_USER}/.ssh"
  chmod 600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
  echo "✅ SSH authorized keys configured."
fi

# ─── 3. SSH Security Hardening ───
echo "🔒 Hardening SSH daemon configuration..."
SSHD_CONFIG="/etc/ssh/sshd_config.d/99-zanko-security.conf"
cat <<EOF > "${SSHD_CONFIG}"
# ZankoAI Production SSH Security
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 2
PermitRootLogin prohibit-password
EOF

# Test and reload ssh
sshd -t && systemctl reload ssh || systemctl reload sshd

# ─── 4. Configure UFW Firewall (Strict Isolation) ───
echo "🛡️ Configuring UFW firewall rules..."
ufw default deny incoming
ufw default allow outgoing

# Allow only SSH, HTTP, and HTTPS
ufw allow 22/tcp comment 'SSH Port'
ufw allow 80/tcp comment 'HTTP (Certbot & HTTPS Redirect)'
ufw allow 443/tcp comment 'HTTPS (Production Traffic)'

# Ensure internal ports (4000 Node, 6379 Redis) are explicitly NOT allowed
ufw status verbose
ufw --force enable
echo "✅ UFW Firewall is enabled and strictly blocking all internal ports."

# ─── 5. Automatic Security Updates ───
echo "🛡️ Enabling unattended security upgrades..."
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

systemctl restart unattended-upgrades
echo "✅ Automatic daily security updates configured."

# ─── 6. Install Official Docker Engine & Docker Compose ───
echo "🐳 Installing Docker Engine and Docker Compose Plugin..."
if ! command -v docker &> /dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "✅ Docker installed successfully."
fi

# Enable Docker on system boot
systemctl enable docker
systemctl start docker

# Add deploy user to docker group
usermod -aG docker "${DEPLOY_USER}"

# ─── 7. Configure Docker Daemon Log Rotation ───
echo "📝 Configuring Docker daemon log rotation (/etc/docker/daemon.json)..."
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "5"
  },
  "live-restore": true
}
EOF

systemctl restart docker

# ─── 8. Automated Disk Space Monitoring ───
echo "💾 Setting up automated disk monitoring script..."
DISK_SCRIPT="/usr/local/bin/zanko_disk_monitor.sh"
cat <<'EOF' > "${DISK_SCRIPT}"
#!/usr/bin/env bash
# Checks root disk utilization and logs warning if > 85%
USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
THRESHOLD=85

if [ "${USAGE}" -ge "${THRESHOLD}" ]; then
  logger -t "ZANKO_MONITOR" -p user.err "CRITICAL: Disk usage on root filesystem is ${USAGE}% (threshold ${THRESHOLD}%)!"
  echo "[ALERT $(date)] Disk space critical: ${USAGE}% used" >> /var/log/zanko_disk_alerts.log
  
  # Clean up dangling docker assets automatically to free space
  docker system prune -f --volumes || true
else
  logger -t "ZANKO_MONITOR" -p user.info "Disk usage healthy: ${USAGE}%"
fi
EOF

chmod +x "${DISK_SCRIPT}"

# Add hourly cron job for disk monitoring
cat <<EOF > /etc/cron.d/zanko_disk_monitor
0 * * * * root ${DISK_SCRIPT} > /dev/null 2>&1
EOF
chmod 644 /etc/cron.d/zanko_disk_monitor

# ─── 9. Prepare Production App Directory ───
echo "📁 Initializing application directory at ${APP_DIR}..."
mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/backend"
mkdir -p "${APP_DIR}/deploy"
mkdir -p /var/www/certbot
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /var/www/certbot

echo "=========================================================="
echo "🎉 Server Provisioning & Hardening Complete!"
echo "• Non-root user: ${DEPLOY_USER}"
echo "• SSH: Password auth disabled, keys enforced"
echo "• UFW: Open ports [22, 80, 443] (4000 & 6379 strictly blocked)"
echo "• Docker: Installed, log rotation enabled, user added"
echo "• Disk Monitor: Hourly check at >85% threshold active"
echo "=========================================================="
