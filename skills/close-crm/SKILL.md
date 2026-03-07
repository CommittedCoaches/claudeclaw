---
name: close-crm
description: Interact with Close CRM API. Use when users ask about Close leads, activities, webhooks, Close CRM data, lead status, call logs, email logs, or anything related to the Close CRM platform. Trigger phrases include "Close CRM", "close lead", "close activity", "create webhook", "lead data", "close API", "call log", "email activity", "close webhook".
---

# Close CRM — Read-Only + Webhook Creation

Access Close CRM data (read-only) and create webhooks.

## Getting Credentials

```bash
CLOSE_API_KEY=$(aws secretsmanager get-secret-value --secret-id CloseAPI --query SecretString --output text --region us-east-2 | jq -r '.api_key // .')
```

The API key is used as HTTP Basic auth username (no password):

```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/<endpoint>"
```

## Available Actions

### List/search leads
```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/lead/?_limit=10" | jq '.data[] | {id, display_name, status_label}'
```

### Get a specific lead
```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/lead/<lead_id>/" | jq .
```

### Search leads by query
```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/lead/" \
  --data-urlencode "query=name:\"Company Name\"" | jq '.data[] | {id, display_name}'
```

### Get activities (calls, emails, etc.)
```bash
# All activities for a lead
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/activity/?lead_id=<lead_id>&_limit=20" | jq '.data[] | {type, date_created, note}'

# Call activities
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/activity/call/?lead_id=<lead_id>&_limit=10" | jq .

# Email activities
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/activity/email/?lead_id=<lead_id>&_limit=10" | jq .
```

### Create a webhook
```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/webhook/" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "<callback_url>",
    "events": [{"object_type": "lead", "action": "updated"}]
  }' | jq .
```

### List webhooks
```bash
curl -s -u "$CLOSE_API_KEY:" "https://api.close.com/api/v1/webhook/" | jq '.data[] | {id, url, events}'
```

## Important
- **Read-only** for leads and activities — no creating, updating, or deleting leads
- **Webhook creation** is allowed — confirm the callback URL with the user first
- Always use `_limit` to avoid pulling too much data
- Close API docs: https://developer.close.com/
- The secret format may vary — inspect with `jq .` first
