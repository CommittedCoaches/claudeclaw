# ClaudeClaw Infrastructure — AWS Deployment

## Architecture Overview

```
Developer (SSM Session Manager)
        |
   EC2 Instance (private subnet, per dev)
   +-------------------------------------------+
   |  ClaudeClaw daemon (runs as dev user)     |
   |  Claude Code CLI (OAuth auth)             |
   |  Shared env: Close, GHL, GrowthBook keys  |
   +-------------------+-----------------------+
                       | (NAT Gateway)
               Anthropic API
```

**Traffic flow:** Claude Code CLI (OAuth) → Anthropic API

Each developer authenticates via **Claude Code OAuth** (browser login). The CLI connects directly to the Anthropic API.

Shared platform keys (Close, GHL, GrowthBook) are stored once in Secrets Manager and loaded into all instances.

All resources live in private subnets within `vpc-0df0fac80f8edeae1` (rds-vpc, us-east-2). No public exposure.

## Auth Model

| Credential | Scope | Where configured |
|---|---|---|
| Claude Code auth | Per-developer (OAuth) | SSM in, run `claude`, log in via browser URL |
| GitHub auth | Per-developer | `onboard-dev.sh` (PAT) or manual `gh auth login` |
| Git email | Per-developer | `onboard-dev.sh` or manual `git config` |
| Telegram bot token | Per-developer | `terraform.tfvars` → baked into instance |
| Telegram user IDs | Per-developer | `terraform.tfvars` → baked into instance |
| Slack user ID | Per-developer | `terraform.tfvars` → baked into instance |
| Close API key | Shared (all devs) | Secrets Manager `claudeclaw/shared-platform-keys` |
| GHL API key | Shared (all devs) | Secrets Manager `claudeclaw/shared-platform-keys` |
| GrowthBook API key | Shared (all devs) | Secrets Manager `claudeclaw/shared-platform-keys` |

## Prerequisites

- Terraform >= 1.10 (for S3-native lockfiles)
- AWS CLI configured with appropriate credentials
- S3 backend bucket `committed-coaches-terraform-state` exists

## Quick Start (Admin)

```bash
cd infra/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with developer list, Telegram tokens, Slack IDs
terraform init
terraform plan
terraform apply
```

After apply:

1. Store shared platform keys:
   ```bash
   aws secretsmanager put-secret-value \
     --secret-id claudeclaw/shared-platform-keys \
     --secret-string '{"CLOSE_API_KEY":"...","GHL_API_KEY":"...","GROWTHBOOK_API_KEY":"..."}'
   ```

2. Share onboarding commands with each developer:
   ```bash
   terraform output onboard_commands
   ```

## Developer Onboarding

**What you need before starting:**
- AWS CLI configured (with permissions to use SSM)
- Your GitHub Personal Access Token (https://github.com/settings/tokens, scopes: `repo`, `read:org`)
- Your git commit email

**Steps:**

1. Run the onboarding script (admin gives you this command):
   ```bash
   ./scripts/onboard-dev.sh <instance-id>
   ```
   This sets up GitHub auth and git email remotely, then opens an SSM session.

2. Inside the SSM session, authenticate with Claude Code:
   ```bash
   claude
   ```
   This shows a URL — paste it in your browser to log in via OAuth.

3. Copy auth credentials to the daemon user and start it:
   ```bash
   sudo /opt/claudeclaw/activate.sh
   ```
   This copies your OAuth credentials from `ssm-user` to the daemon's Linux user, clones all configured repos to `~/repos/`, sets up gh as git credential helper, and starts ClaudeClaw.

**Alternative (fully manual):** SSM in and run `setup.sh` which walks through all steps interactively:
```bash
aws ssm start-session --target <instance-id>
bash /opt/claudeclaw/<dev_name>/setup.sh
sudo /opt/claudeclaw/activate.sh
```

### Onboarding Checklist

For **admins** adding a new developer:
- [ ] Add dev to `terraform.tfvars` (instance_type, github_username, slack_user_id, telegram_token, telegram_user_ids, extra_repos)
- [ ] `terraform apply`
- [ ] Share `terraform output onboard_commands` output with the developer
- [ ] Ensure shared platform keys are populated in Secrets Manager

For **developers** setting up their instance:
- [ ] Run `onboard-dev.sh <instance-id>` (provides GitHub PAT + git email)
- [ ] Inside SSM session, run `claude` and complete OAuth login via browser
- [ ] Run `sudo /opt/claudeclaw/activate.sh` — starts daemon + clones repos
- [ ] Verify daemon: `sudo systemctl status claudeclaw`
- [ ] Verify repos cloned: `ls ~/repos/`
- [ ] Test Telegram: send a message to your bot
- [ ] (Optional) Access web UI via SSM port forwarding on port 4632

## Adding a New Developer

### Self-service (new dev creates a PR)

1. Fork the repo and add your entry to `infra/developers.yaml`:
   ```yaml
   your_name:
     github_username: your-github-username
     slack_user_id: "U..."           # Slack profile -> More -> Copy member ID
     telegram_user_ids: [123456789]  # @userinfobot on Telegram -> your numeric ID
     extra_repos: []                 # additional repos beyond the shared set
   ```

2. Create a PR. CI will validate your config — fix any errors it reports.

3. After merge, the PR gets a comment with your onboarding steps.

4. An admin adds your secrets (telegram_token, slack_token) to `terraform.tfvars`, runs `terraform apply`, and shares your instance ID.

### Admin-only (manual)

1. Add the dev to both `infra/developers.yaml` and `terraform.tfvars` (for secrets).
2. `terraform apply`
3. Share the onboard command: `terraform output onboard_commands`

## Configured Repos

Repos are cloned to `~/repos/` during `activate.sh`. Configured in `variables.tf`:

**Shared (all devs):** admin-server, data, cc_utils, booking-calendar-sync, lambda, queue-consumers, control-panel, appointment-distribution, cc_rules, ac-booking-calendar-sync, five9-scripts

**Per-dev extras:** Set `extra_repos` in `terraform.tfvars` for additional repos.

## Slack Setup (Per-Developer)

Each developer needs their own Slack user token from a Slack app with read-only permissions.

1. **Create a Slack app** at https://api.slack.com/apps → "Create New App" → "From scratch"
2. **Add OAuth scopes** under "OAuth & Permissions" → "User Token Scopes":
   - `channels:history` — View messages in public channels
   - `channels:read` — View basic info about public channels
   - `groups:history` — View messages in private channels
   - `groups:read` — View basic info about private channels
   - `im:history` — View messages in DMs
   - `im:read` — View basic info about DMs
   - `mpim:history` — View messages in group DMs
   - `mpim:read` — View basic info about group DMs
   - `search:read` — Search workspace content
   - `users:read` — View people in workspace
3. **Install the app** to the workspace under "Install App"
4. **Copy the User OAuth Token** (`xoxp-...`) and add it to `terraform.tfvars`:
   ```hcl
   slack_token = "xoxp-..."
   ```

## Adding Shared Platform Keys

To add a new shared key accessible to all instances:

1. Update the secret:
   ```bash
   # Get current value
   aws secretsmanager get-secret-value --secret-id claudeclaw/shared-platform-keys \
     --query SecretString --output text | jq '. + {"NEW_API_KEY": "value"}' > /tmp/keys.json

   aws secretsmanager put-secret-value \
     --secret-id claudeclaw/shared-platform-keys \
     --secret-string file:///tmp/keys.json

   rm /tmp/keys.json
   ```

2. On each instance, reload the env (or reboot):
   ```bash
   # Re-fetch from Secrets Manager
   aws secretsmanager get-secret-value --secret-id claudeclaw/shared-platform-keys \
     --query SecretString --output text | \
     jq -r 'to_entries[] | "export \(.key)=\(.value)"' > /opt/claudeclaw/shared-env.sh
   sudo systemctl restart claudeclaw
   ```

## Managing Permissions

### Per-Developer (single instance)

**Security level** -- edit `settings.json` or use `/claudeclaw:config security level <level>`:

| Level | Tools Available | Directory Scoped |
|-------|----------------|-----------------|
| `locked` | Read, Grep, Glob only | Yes |
| `strict` | Everything except Bash, WebSearch, WebFetch | Yes |
| `moderate` | All tools (default) | Yes |
| `unrestricted` | All tools | No |

**IAM permissions** -- set per-dev in `terraform.tfvars`:
- Default: restricted (CloudWatch + Airflow + Secrets Manager only)
- Admin: `iam_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]`

### Org-Wide (all instances)

**Shared prompts** -- modify in the repo, then `git pull` on instances:
- `prompts/SOUL.md` -- behavior guidelines, communication style
- `prompts/IDENTITY.md` -- assistant personality
- `prompts/USER.md` -- shared context about the team

## Re-authenticating Claude Code

If a dev's OAuth session expires:

1. SSM into their instance:
   ```bash
   aws ssm start-session --target <instance-id>
   ```
2. Re-authenticate and restart:
   ```bash
   claude
   sudo /opt/claudeclaw/activate.sh
   ```

## Rotating Shared Platform Keys

1. Update the Secrets Manager secret (see "Adding Shared Platform Keys").
2. Reload on each instance or reboot.

## Accessing the Web Dashboard

Via SSM port forwarding (no public exposure):

```bash
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=4632,localPortNumber=4632
```

Then open `http://localhost:4632`

## Security Details

| Requirement | Implementation |
|---|---|
| Per-dev Claude auth | OAuth login via `claude` CLI on each instance |
| Per-dev GitHub auth | `gh auth login` via onboarding script or setup.sh |
| Shared platform keys | Secrets Manager → env file on each instance |
| IAM restricted by default | Restricted IAM policy; admin override via `iam_policy_arns` |
| Non-root daemon | systemd service runs as the dev's Linux user |
| No SSH | SSM Session Manager only; zero ingress security group rules |
| fail2ban | Installed and configured via userdata |
| Firewall | Security groups: no ingress, egress to internet only |
| Network segmentation | All resources in private subnets |
| Audit logging | CloudTrail |
| MFA enforcement | IAM policy denying actions without MFA |
| Daily security audit | systemd timer running `security-audit.sh` |

## Verification Checklist

- [ ] `terraform plan` shows expected resources
- [ ] SSM session: `aws ssm start-session --target <id>`
- [ ] `claude` auth completes successfully
- [ ] `gh auth status` shows authenticated
- [ ] ClaudeClaw daemon running: `systemctl status claudeclaw`
- [ ] Shared env vars loaded: `source /opt/claudeclaw/shared-env.sh && env | grep API`
- [ ] Security audit timer: `systemctl status claudeclaw-audit.timer`
- [ ] fail2ban active: `fail2ban-client status`
- [ ] EC2 has no public IP
- [ ] CloudTrail logging active
