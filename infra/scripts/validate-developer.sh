#!/bin/bash
set -euo pipefail

# Validates developers.yaml entries.
# Called by CI on PRs that modify infra/developers.yaml.
# Exits 0 on success, 1 on failure with human-readable error messages.

DEVS_FILE="infra/developers.yaml"
ERRORS=()

if [ ! -f "$DEVS_FILE" ]; then
  echo "::error::$DEVS_FILE not found"
  exit 1
fi

# Check valid YAML
if ! python3 -c "import yaml; yaml.safe_load(open('$DEVS_FILE'))" 2>/dev/null; then
  echo "::error::$DEVS_FILE is not valid YAML"
  exit 1
fi

# Get list of developer names (top-level keys, skip comments)
DEVS=$(python3 -c "
import yaml, sys
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
if not data:
    sys.exit(0)
for name in data:
    print(name)
")

if [ -z "$DEVS" ]; then
  echo "No developers found in $DEVS_FILE"
  exit 0
fi

while IFS= read -r DEV_NAME; do
  # Validate dev name format
  if ! echo "$DEV_NAME" | grep -qE '^[a-z0-9_-]+$'; then
    ERRORS+=("[$DEV_NAME] Name must contain only lowercase letters, digits, hyphens, and underscores")
  fi

  # Extract fields
  GITHUB_USERNAME=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
print(dev.get('github_username', ''))
")

  SLACK_USER_ID=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
print(dev.get('slack_user_id', ''))
")

  INSTANCE_TYPE=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
print(dev.get('instance_type', 't3.medium'))
")

  TELEGRAM_IDS=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
ids = dev.get('telegram_user_ids', [])
if not isinstance(ids, list):
    print('INVALID')
else:
    for i in ids:
        if not isinstance(i, int):
            print('INVALID')
            break
    else:
        print('OK')
")

  IAM_ARNS=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
arns = dev.get('iam_policy_arns', [])
if not isinstance(arns, list):
    print('INVALID')
else:
    for a in arns:
        if not isinstance(a, str) or not a.startswith('arn:aws:iam:'):
            print('INVALID')
            break
    else:
        print('OK')
")

  EXTRA_REPOS=$(python3 -c "
import yaml
with open('$DEVS_FILE') as f:
    data = yaml.safe_load(f)
dev = data.get('$DEV_NAME', {})
repos = dev.get('extra_repos', [])
if not isinstance(repos, list):
    print('INVALID')
else:
    for r in repos:
        if not isinstance(r, str):
            print('INVALID')
            break
    else:
        print('OK')
")

  # Required: github_username
  if [ -z "$GITHUB_USERNAME" ]; then
    ERRORS+=("[$DEV_NAME] Missing required field: github_username")
  elif ! echo "$GITHUB_USERNAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    ERRORS+=("[$DEV_NAME] github_username '$GITHUB_USERNAME' contains invalid characters (use alphanumeric, hyphens, underscores)")
  fi

  # Optional but validated: slack_user_id
  if [ -n "$SLACK_USER_ID" ] && ! echo "$SLACK_USER_ID" | grep -qE '^U[A-Z0-9]+$'; then
    ERRORS+=("[$DEV_NAME] slack_user_id '$SLACK_USER_ID' must start with 'U' followed by uppercase alphanumeric (find it in Slack profile -> More -> Copy member ID)")
  fi

  # Validate instance_type format
  if ! echo "$INSTANCE_TYPE" | grep -qE '^[a-z][a-z0-9]*\.[a-z0-9]+$'; then
    ERRORS+=("[$DEV_NAME] instance_type '$INSTANCE_TYPE' doesn't look like a valid EC2 instance type (e.g. t3.medium)")
  fi

  # Validate telegram_user_ids
  if [ "$TELEGRAM_IDS" = "INVALID" ]; then
    ERRORS+=("[$DEV_NAME] telegram_user_ids must be a list of numbers (use @userinfobot on Telegram to get your ID)")
  fi

  # Validate iam_policy_arns
  if [ "$IAM_ARNS" = "INVALID" ]; then
    ERRORS+=("[$DEV_NAME] iam_policy_arns must be a list of valid ARNs starting with 'arn:aws:iam:' (or remove the field for default restricted access)")
  fi

  # Validate extra_repos
  if [ "$EXTRA_REPOS" = "INVALID" ]; then
    ERRORS+=("[$DEV_NAME] extra_repos must be a list of strings")
  fi

done <<< "$DEVS"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "=== Developer config validation failed ==="
  echo ""
  for err in "${ERRORS[@]}"; do
    echo "::error::$err"
    echo "  - $err"
  done
  echo ""
  echo "Fix the issues above in infra/developers.yaml and push again."
  exit 1
fi

echo "All developer entries in $DEVS_FILE are valid."
exit 0
