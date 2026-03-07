---
name: five9
description: Interact with Five9 contact center platform. Use when users ask about Five9, call scripts, campaigns, Five9 reporting, Five9 data, agent stats, or anything related to Five9. Trigger phrases include "Five9", "five9 script", "five9 report", "campaign data", "call center", "agent stats", "five9 API", "IVR script", "five9 campaign".
---

# Five9 — Scripts, Reporting & Campaign Reader

Create Five9 scripts (stored in repo), read reporting data, and read campaign info.

## Getting Credentials

```bash
FIVE9_CREDS=$(aws secretsmanager get-secret-value --secret-id airflow/five9-credentials --query SecretString --output text --region us-east-2)
FIVE9_USER=$(echo $FIVE9_CREDS | jq -r '.username // .user')
FIVE9_PASS=$(echo $FIVE9_CREDS | jq -r '.password // .pass')
```

Or individual secrets:
```bash
FIVE9_USER=$(aws secretsmanager get-secret-value --secret-id FIVE9_USERNAME --query SecretString --output text --region us-east-2)
FIVE9_PASS=$(aws secretsmanager get-secret-value --secret-id FIVE9_PASSWORD --query SecretString --output text --region us-east-2)
```

## Five9 API Access

Five9 uses a SOAP/REST API with basic auth:

```bash
# Configuration API (SOAP) — for campaigns, scripts, etc.
curl -s -u "$FIVE9_USER:$FIVE9_PASS" \
  "https://api.five9.com/wsadmin/v12/AdminWebService" \
  -H "Content-Type: text/xml" \
  -d '<soapenv:Envelope>...</soapenv:Envelope>'

# Statistics/Reporting API
curl -s -u "$FIVE9_USER:$FIVE9_PASS" \
  "https://api.five9.com/wsadmin/v12/AdminWebService" \
  -H "Content-Type: text/xml" \
  -d '<soapenv:Envelope>...</soapenv:Envelope>'
```

## Script Development

Five9 scripts are normal code — write them and store in the `five9-scripts` repo:

```bash
# Clone if not already present
gh repo clone CommittedCoaches/five9-scripts /opt/claudeclaw/repos/five9-scripts 2>/dev/null || true
cd /opt/claudeclaw/repos/five9-scripts
```

1. Write the script code
2. Commit to a branch
3. Create a PR for review
4. Scripts are executed by humans, not by the agent

## Reporting Access

For reporting, use the Five9 Statistics API or the reporting account credentials to pull agent stats, call logs, and campaign metrics.

## Important
- **Scripts**: Write code, store in `five9-scripts` repo, create PR. Never execute directly.
- **Reporting**: Read-only access to reports and stats
- **Campaigns**: Can read campaign data. Note: Five9 API doesn't separate read/write well — only USE read endpoints
- **Five9 VCC Management**: Keep separate from general use — only interact with the five9-scripts repo and reporting API
- Inspect credentials first: `echo $FIVE9_CREDS | jq .`
