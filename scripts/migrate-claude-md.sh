#!/bin/bash
# Migrates CLAUDE.md to separate user content from managed block.
# The managed block will only contain SOUL.md (auto-updated on deploy).
# Identity, user info, repos etc stay outside the managed block.
set -euo pipefail

CLAUDE_MD="${1:-CLAUDE.md}"
if [ ! -f "$CLAUDE_MD" ]; then
  echo "File not found: $CLAUDE_MD"
  exit 1
fi

# Check if it has a managed block
if ! grep -q "claudeclaw:managed:start" "$CLAUDE_MD"; then
  echo "No managed block found, skipping"
  exit 0
fi

# Extract content between managed markers
MANAGED_CONTENT=$(sed -n '/claudeclaw:managed:start/,/claudeclaw:managed:end/p' "$CLAUDE_MD" | \
  grep -v 'claudeclaw:managed')

# Check if identity/user info is inside the managed block (old format)
if echo "$MANAGED_CONTENT" | grep -q "Core Truths\|Be genuinely helpful\|You're not a chatbot"; then
  echo "Detected old format (SOUL.md baked into managed block). Migrating..."

  # Extract identity section (before Core Truths / first ## heading that's SOUL content)
  USER_CONTENT=$(echo "$MANAGED_CONTENT" | sed '/^_You.re not a chatbot/,$d' | sed '/^## Core Truths/,$d')

  # Write new CLAUDE.md: user content outside, empty managed block (will be filled on next boot)
  cat > "$CLAUDE_MD" <<EOF
${USER_CONTENT}
<!-- claudeclaw:managed:start -->
<!-- claudeclaw:managed:end -->
EOF
  echo "Migrated: user content preserved, SOUL.md removed from managed block"
else
  echo "Already in new format, skipping"
fi
