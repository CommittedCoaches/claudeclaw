#!/bin/bash
# ClaudeClaw Daily Security Audit Script
# Runs via systemd timer (claudeclaw-audit.timer)

set -euo pipefail

LOG_DIR="/var/log/claudeclaw"
mkdir -p "$LOG_DIR"
REPORT="$LOG_DIR/security-audit-$(date +%Y%m%d-%H%M%S).log"

# Retain last 30 audit reports
find "$LOG_DIR" -name "security-audit-*.log" -mtime +30 -delete 2>/dev/null || true

echo "=== ClaudeClaw Security Audit ===" > "$REPORT"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$REPORT"
echo "Hostname: $(hostname)" >> "$REPORT"
echo "" >> "$REPORT"

# 1. Check for open/listening ports
echo "--- Listening Ports ---" >> "$REPORT"
ss -tlnp 2>/dev/null >> "$REPORT" || netstat -tlnp 2>/dev/null >> "$REPORT" || echo "Unable to check ports" >> "$REPORT"
echo "" >> "$REPORT"

# 2. Failed login attempts
echo "--- Failed Login Attempts (last 24h) ---" >> "$REPORT"
journalctl -u ssh --since "24 hours ago" --no-pager 2>/dev/null | grep -i "failed\|invalid" >> "$REPORT" || echo "No failed logins found" >> "$REPORT"
echo "" >> "$REPORT"

# 3. Disk usage
echo "--- Disk Usage ---" >> "$REPORT"
df -h >> "$REPORT"
echo "" >> "$REPORT"

# 4. Top processes by memory
echo "--- Top 10 Processes by Memory ---" >> "$REPORT"
ps aux --sort=-%mem | head -11 >> "$REPORT"
echo "" >> "$REPORT"

# 5. World-writable files in /opt/claudeclaw
echo "--- World-Writable Files in /opt/claudeclaw ---" >> "$REPORT"
find /opt/claudeclaw -type f -perm -002 2>/dev/null >> "$REPORT" || echo "None found" >> "$REPORT"
echo "" >> "$REPORT"

# 6. fail2ban status
echo "--- fail2ban Status ---" >> "$REPORT"
fail2ban-client status 2>/dev/null >> "$REPORT" || echo "fail2ban not running" >> "$REPORT"
echo "" >> "$REPORT"

# 7. SSM Agent status
echo "--- SSM Agent Status ---" >> "$REPORT"
systemctl is-active snap.amazon-ssm-agent.amazon-ssm-agent.service >> "$REPORT" 2>/dev/null || echo "SSM agent not running" >> "$REPORT"
echo "" >> "$REPORT"

# 8. ClaudeClaw daemon status
echo "--- ClaudeClaw Daemon Status ---" >> "$REPORT"
systemctl is-active claudeclaw.service >> "$REPORT" 2>/dev/null || echo "ClaudeClaw daemon not running" >> "$REPORT"
echo "" >> "$REPORT"

# 9. Check for unauthorized SSH keys
echo "--- Authorized SSH Keys ---" >> "$REPORT"
for user_home in /home/* /root; do
  auth_keys="$user_home/.ssh/authorized_keys"
  if [ -f "$auth_keys" ]; then
    echo "$auth_keys:" >> "$REPORT"
    wc -l < "$auth_keys" >> "$REPORT"
  fi
done
echo "" >> "$REPORT"

echo "=== Audit Complete ===" >> "$REPORT"
echo "[$(date)] Security audit saved to $REPORT"
