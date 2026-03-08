#!/bin/bash
set -euo pipefail

exec > /var/log/claudeclaw-userdata.log 2>&1
echo "[$(date)] Starting ClaudeClaw bootstrap for ${dev_name}..."

# Ensure HOME is set (cloud-init may not set it)
export HOME="/root"

# --- 1. System packages ---
apt-get update -y
apt-get install -y curl git jq unzip fail2ban

# --- 2. Install Bun ---
echo "[$(date)] Installing Bun..."
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="/root/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# --- 3. Install Node.js 20 LTS (needed for ogg-opus-decoder) ---
echo "[$(date)] Installing Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# --- 4. Install Claude Code CLI + GitHub CLI ---
echo "[$(date)] Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

echo "[$(date)] Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update -y
apt-get install -y gh

# --- 5. Install/verify SSM Agent ---
echo "[$(date)] Ensuring SSM Agent is running..."
snap install amazon-ssm-agent --classic 2>/dev/null || true
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# --- 6. Create dev user and clone ClaudeClaw ---
id ${dev_name} 2>/dev/null || useradd -m -s /bin/bash ${dev_name}
cp -r /root/.bun /home/${dev_name}/.bun
chown -R ${dev_name}:${dev_name} /home/${dev_name}/.bun

INSTALL_DIR="/opt/claudeclaw/${dev_name}"
echo "[$(date)] Cloning ClaudeClaw to $INSTALL_DIR..."
mkdir -p /opt/claudeclaw
git clone ${repo_url} "$INSTALL_DIR"
chown -R ${dev_name}:${dev_name} "$INSTALL_DIR"
cd "$INSTALL_DIR"
bun install

# --- 6b. Prepare repos directory (cloning happens in activate.sh after gh auth) ---
echo "[$(date)] Preparing repos directory..."
REPOS_DIR="/home/${dev_name}/repos"
mkdir -p "$REPOS_DIR"
chown -R ${dev_name}:${dev_name} "$REPOS_DIR"

# --- 7. Load shared platform secrets and write env file ---
echo "[$(date)] Loading shared platform secrets..."
SHARED_SECRETS=$(aws secretsmanager get-secret-value \
  --secret-id "${shared_platform_secret_arn}" \
  --query SecretString --output text 2>/dev/null || echo '{}')

cat > /opt/claudeclaw/shared-env.sh <<ENVEOF
# Shared platform keys — sourced by ClaudeClaw and setup script
# Auto-generated from Secrets Manager. Do not edit manually.
$(echo "$SHARED_SECRETS" | jq -r 'to_entries[] | "export \(.key)=\(.value | @sh)"')
%{ if slack_token != "" ~}
export SLACK_USER_TOKEN='${slack_token}'
%{ endif ~}
ENVEOF
chmod 600 /opt/claudeclaw/shared-env.sh

# --- 8. Write initial settings.json (api left blank — set during onboarding) ---
echo "[$(date)] Writing settings.json..."
mkdir -p "$INSTALL_DIR/.claude/claudeclaw"
cat > "$INSTALL_DIR/.claude/claudeclaw/settings.json" <<SETTINGS_EOF
{
  "model": "claude-sonnet-4-6",
  "api": "",
  "proxyUrl": "",
  "fallback": {
    "model": "claude-opus-4-6",
    "api": "",
    "proxyUrl": ""
  },
  "timezone": "UTC",
  "timezoneOffsetMinutes": 0,
  "heartbeat": {
    "enabled": false,
    "interval": 15,
    "prompt": "",
    "excludeWindows": []
  },
  "telegram": {
    "token": "${telegram_token}",
    "allowedUserIds": ${telegram_user_ids}
  },
  "security": {
    "level": "moderate",
    "allowedTools": [],
    "disallowedTools": []
  },
  "web": {
    "enabled": true,
    "host": "127.0.0.1",
    "port": 4632
  },
  "stt": {
    "baseUrl": "",
    "model": ""
  }
}
SETTINGS_EOF

# --- 9. Create developer onboarding script ---
echo "[$(date)] Creating onboarding script..."
cat > /opt/claudeclaw/${dev_name}/setup.sh <<'SETUP_EOF'
#!/bin/bash
set -euo pipefail

INSTALL_DIR="/opt/claudeclaw/${dev_name}"
SETTINGS="$INSTALL_DIR/.claude/claudeclaw/settings.json"

echo ""
echo "=========================================="
echo "  ClaudeClaw Developer Onboarding"
echo "  Instance: ${dev_name}"
echo "=========================================="
echo ""

# --- 1. Claude Code Authentication ---
echo "1) Claude Code Authentication"
if claude auth status &>/dev/null 2>&1; then
  echo "   [OK] Already authenticated with Claude Code."
else
  echo "   Run 'claude' to authenticate via browser."
  echo "   It will show a URL — paste it in your browser to log in."
  echo ""
  claude
fi
echo ""

# --- 2. GitHub Authentication ---
echo "2) GitHub Authentication"
echo "   This lets you push/pull as yourself."
echo ""
if gh auth status &>/dev/null; then
  echo "   [OK] Already authenticated with GitHub."
else
  echo "   Create a token at: https://github.com/settings/tokens"
  echo "   Required scopes: repo, read:org"
  echo ""
  read -rp "   GitHub Personal Access Token: " GH_TOKEN
  if [ -n "$GH_TOKEN" ]; then
    echo "$GH_TOKEN" | gh auth login --with-token
    git config --global user.name "${github_username}"
    echo "   [OK] GitHub authenticated."
  else
    echo "   [SKIP] Run 'gh auth login' later."
  fi
fi
echo ""

# --- 3. Git user email ---
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
if [ -z "$CURRENT_EMAIL" ]; then
  echo "3) Git Email"
  read -rp "   Your git commit email: " GIT_EMAIL
  if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
    echo "   [OK] Git email set."
  fi
  echo ""
fi

# --- 4. Shared platform keys ---
echo "4) Shared Platform Keys"
if [ -f /opt/claudeclaw/shared-env.sh ]; then
  echo "   The following shared keys are available:"
  grep "^export " /opt/claudeclaw/shared-env.sh | sed 's/=.*//' | sed 's/export /   - /'
  echo "   These are auto-loaded from Secrets Manager."
else
  echo "   [WARN] No shared platform keys found."
fi
echo ""

# --- Summary ---
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "  Start ClaudeClaw:  systemctl start claudeclaw"
echo "  Check status:      systemctl status claudeclaw"
echo "  View logs:         tail -f $INSTALL_DIR/.claude/claudeclaw/logs/daemon.log"
echo "  Rerun setup:       bash $INSTALL_DIR/setup.sh"
echo ""
SETUP_EOF
chmod +x /opt/claudeclaw/${dev_name}/setup.sh

# --- 10. Configure fail2ban ---
echo "[$(date)] Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<'F2B_EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
F2B_EOF

systemctl enable fail2ban
systemctl restart fail2ban

# --- 11. Create systemd service for ClaudeClaw ---
echo "[$(date)] Creating ClaudeClaw systemd service..."
cat > /etc/systemd/system/claudeclaw.service <<SYSD_EOF
[Unit]
Description=ClaudeClaw Daemon for ${dev_name}
After=network.target

[Service]
Type=simple
User=${dev_name}
Group=${dev_name}
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=/opt/claudeclaw/shared-env.sh
Environment=HOME=/home/${dev_name}
Environment=PATH=/home/${dev_name}/.bun/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/${dev_name}/.bun/bin/bun run src/index.ts start --web
Restart=on-failure
RestartSec=10
StandardOutput=append:$INSTALL_DIR/.claude/claudeclaw/logs/daemon.log
StandardError=append:$INSTALL_DIR/.claude/claudeclaw/logs/daemon.log

[Install]
WantedBy=multi-user.target
SYSD_EOF

mkdir -p "$INSTALL_DIR/.claude/claudeclaw/logs"
chown -R ${dev_name}:${dev_name} "$INSTALL_DIR/.claude"
systemctl daemon-reload
systemctl enable claudeclaw.service
# NOTE: Don't auto-start — dev must run setup.sh first to provide their Anthropic key

# --- 12. Create daily security audit timer ---
echo "[$(date)] Setting up security audit timer..."
cp "$INSTALL_DIR/infra/scripts/security-audit.sh" /usr/local/bin/claudeclaw-security-audit.sh
chmod +x /usr/local/bin/claudeclaw-security-audit.sh

cat > /etc/systemd/system/claudeclaw-audit.service <<'AUDIT_SVC_EOF'
[Unit]
Description=ClaudeClaw Daily Security Audit

[Service]
Type=oneshot
ExecStart=/usr/local/bin/claudeclaw-security-audit.sh
AUDIT_SVC_EOF

cat > /etc/systemd/system/claudeclaw-audit.timer <<'AUDIT_TMR_EOF'
[Unit]
Description=Run ClaudeClaw security audit daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
AUDIT_TMR_EOF

systemctl daemon-reload
systemctl enable claudeclaw-audit.timer
systemctl start claudeclaw-audit.timer

# --- 13. Create activate script (copies OAuth creds from ssm-user to dev user) ---
echo "[$(date)] Creating activate script..."
cat > /opt/claudeclaw/activate.sh <<'ACTIVATE_EOF'
#!/bin/bash
set -euo pipefail
DEV_USER=$(ls /opt/claudeclaw/ | grep -v -E 'shared-env|activate' | head -1)
SSM_CREDS="/home/ssm-user/.claude/.credentials.json"

# Copy Claude OAuth credentials
if [ -f "$SSM_CREDS" ]; then
  mkdir -p "/home/$DEV_USER/.claude"
  cp "$SSM_CREDS" "/home/$DEV_USER/.claude/.credentials.json"
  chown -R "$DEV_USER:$DEV_USER" "/home/$DEV_USER/.claude"
  chmod 600 "/home/$DEV_USER/.claude/.credentials.json"
  echo "Claude auth: copied"
else
  echo "Warning: No Claude credentials found. Run 'claude' first to authenticate."
fi

# Copy gh auth from root or ssm-user to dev user
for SRC_HOME in /root /home/ssm-user; do
  if [ -f "$SRC_HOME/.config/gh/hosts.yml" ]; then
    mkdir -p "/home/$DEV_USER/.config/gh"
    cp "$SRC_HOME/.config/gh/hosts.yml" "/home/$DEV_USER/.config/gh/hosts.yml"
    cp "$SRC_HOME/.config/gh/config.yml" "/home/$DEV_USER/.config/gh/config.yml" 2>/dev/null || true
    chown -R "$DEV_USER:$DEV_USER" "/home/$DEV_USER/.config"
    echo "GitHub auth: copied from $SRC_HOME"
    break
  fi
done

# Copy git config from root or ssm-user
for SRC_HOME in /root /home/ssm-user; do
  if [ -f "$SRC_HOME/.gitconfig" ]; then
    cp "$SRC_HOME/.gitconfig" "/home/$DEV_USER/.gitconfig"
    chown "$DEV_USER:$DEV_USER" "/home/$DEV_USER/.gitconfig"
    echo "Git config: copied from $SRC_HOME"
    break
  fi
done

# Set up gh as git credential helper
su - "$DEV_USER" -c "gh auth setup-git" 2>/dev/null || true

# Clone org repos using gh token for auth
REPOS_DIR="/home/$DEV_USER/repos"
CLONE_REPOS='${clone_repos}'
GH_TOKEN=""
if [ -f "/home/$DEV_USER/.config/gh/hosts.yml" ]; then
  GH_TOKEN=$(grep oauth_token "/home/$DEV_USER/.config/gh/hosts.yml" | head -1 | awk '{print $2}')
fi
if [ -n "$CLONE_REPOS" ] && [ "$CLONE_REPOS" != "[]" ] && [ -n "$GH_TOKEN" ]; then
  echo "Cloning org repos..."
  mkdir -p "$REPOS_DIR"
  export HOME=/root
  git config --global --add safe.directory "*"
  for REPO in $(echo "$CLONE_REPOS" | jq -r '.[]'); do
    if [ ! -d "$REPOS_DIR/$REPO" ]; then
      git clone "https://x-access-token:$GH_TOKEN@github.com/CommittedCoaches/$REPO.git" "$REPOS_DIR/$REPO" 2>&1 && echo "  $REPO: cloned" || echo "  $REPO: failed"
    else
      echo "  $REPO: already exists"
    fi
  done
  # Remove embedded tokens from remote URLs (use gh credential helper instead)
  for D in "$REPOS_DIR"/*/; do
    REPO=$(basename "$D")
    git -C "$D" remote set-url origin "https://github.com/CommittedCoaches/$REPO.git" 2>/dev/null || true
  done
  git config --global --unset-all safe.directory 2>/dev/null || true
  chown -R "$DEV_USER:$DEV_USER" "$REPOS_DIR"
elif [ -n "$CLONE_REPOS" ] && [ "$CLONE_REPOS" != "[]" ]; then
  echo "Skipping repo cloning — no GitHub token found. Run 'gh auth login' then re-run activate.sh"
fi

systemctl restart claudeclaw
sleep 2
if systemctl is-active --quiet claudeclaw; then
  echo "ClaudeClaw is running!"
else
  echo "Error: daemon failed to start. Check: journalctl -u claudeclaw -n 20"
fi
ACTIVATE_EOF
chmod +x /opt/claudeclaw/activate.sh

# --- 14. Print MOTD for SSM sessions ---
cat > /etc/motd <<MOTD_EOF

  ClaudeClaw Instance: ${dev_name}
  ----------------------------------------
  First time?
    1. Run:  claude              (authenticate via browser)
    2. Run:  sudo /opt/claudeclaw/activate.sh   (start daemon)
  View logs:  tail -f /opt/claudeclaw/${dev_name}/.claude/claudeclaw/logs/daemon.log

MOTD_EOF

echo "[$(date)] ClaudeClaw bootstrap complete for ${dev_name}."
echo "[$(date)] Developer must SSM in, run 'claude' to auth, then 'sudo /opt/claudeclaw/activate.sh'"
