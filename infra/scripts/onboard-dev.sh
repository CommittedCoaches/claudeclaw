#!/bin/bash
set -euo pipefail

# Usage: ./onboard-dev.sh <instance-id>
# Collects GitHub token and git email locally, configures the remote instance
# via SSM, then opens an SSM session for Claude Code OAuth login.
#
# After OAuth, credentials are auto-copied to the dev user and the daemon starts.

INSTANCE_ID="${1:-}"
REGION="${AWS_DEFAULT_REGION:-us-east-2}"

if [ -z "$INSTANCE_ID" ]; then
  echo "Usage: ./onboard-dev.sh <instance-id>"
  echo ""
  echo "Find your instance ID in the Terraform output or ask your admin."
  exit 1
fi

echo ""
echo "=========================================="
echo "  ClaudeClaw Developer Onboarding"
echo "=========================================="
echo ""

# --- Collect credentials locally ---

read -rp "GitHub Personal Access Token (scopes: repo, read:org): " GITHUB_TOKEN
echo ""
read -rp "Git commit email: " GIT_EMAIL
echo ""

echo "Configuring instance ${INSTANCE_ID}..."

# --- Send setup commands via SSM ---
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --timeout-seconds 120 \
  --region "$REGION" \
  --parameters "{\"commands\":[
    \"export HOME=/root\",
    \"DEV_USER=\$(ls /opt/claudeclaw/ | head -1)\",
    \"echo '$GITHUB_TOKEN' | su -c 'gh auth login --with-token' \$DEV_USER 2>/dev/null && echo 'GitHub: OK' || echo 'GitHub: skipped'\",
    \"su -c \\\"git config --global user.email '$GIT_EMAIL'\\\" \$DEV_USER\",
    \"su -c \\\"git config --global user.name \$DEV_USER\\\" \$DEV_USER\",
    \"echo \\\"Dev user: \$DEV_USER\\\"\"
  ]}" \
  --query 'Command.CommandId' --output text)

echo "Waiting for remote setup (command: ${CMD_ID})..."

# Poll for completion
for i in $(seq 1 30); do
  sleep 3
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Status' --output text 2>/dev/null || echo "Pending")

  if [ "$STATUS" = "Success" ]; then
    OUTPUT=$(aws ssm get-command-invocation \
      --command-id "$CMD_ID" \
      --instance-id "$INSTANCE_ID" \
      --region "$REGION" \
      --query 'StandardOutputContent' --output text)
    echo ""
    echo "$OUTPUT"
    echo ""
    echo "=========================================="
    echo "  GitHub & git configured!"
    echo "=========================================="
    echo ""
    echo "  Next: SSM in and authenticate Claude Code."
    echo "  The session will open automatically."
    echo ""
    echo "  Once inside, run these commands:"
    echo ""
    echo "    claude            # log in via the browser URL"
    echo "    sudo /opt/claudeclaw/activate.sh   # copies auth & starts daemon"
    echo ""
    break
  elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "TimedOut" ]; then
    ERROR=$(aws ssm get-command-invocation \
      --command-id "$CMD_ID" \
      --instance-id "$INSTANCE_ID" \
      --region "$REGION" \
      --query 'StandardErrorContent' --output text)
    echo ""
    echo "Setup failed: $ERROR"
    exit 1
  fi
done

# Offer to open SSM session directly
echo ""
read -rp "Open SSM session now? [Y/n]: " OPEN_SSM
if [ "${OPEN_SSM:-Y}" != "n" ] && [ "${OPEN_SSM:-Y}" != "N" ]; then
  exec aws ssm start-session --target "$INSTANCE_ID" --region "$REGION"
fi
