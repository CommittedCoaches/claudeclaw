---
name: slack-reader
description: Read Slack channels and messages. Use when users ask to check Slack, read a channel, see recent messages, search Slack, check what was said in a channel, or monitor Slack. Trigger phrases include "check Slack", "Slack messages", "read channel", "what's in Slack", "Slack search", "recent messages in", "check #channel".
---

# Slack — Read-Only with Allowlist

Read Slack channels and messages. Bot can only be triggered by approved persons.

## Getting Credentials

```bash
SLACK_CREDS=$(aws secretsmanager get-secret-value --secret-id airflow/slack-bot-tokens --query SecretString --output text --region us-east-2)
SLACK_TOKEN=$(echo $SLACK_CREDS | jq -r '.bot_token // .token // keys[0] as $k | .[$k]')
```

Inspect the secret structure first:
```bash
echo $SLACK_CREDS | jq .
```

## API Usage

### List channels
```bash
curl -s "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=100" \
  -H "Authorization: Bearer $SLACK_TOKEN" | jq '.channels[] | {id, name}'
```

### Read channel history
```bash
curl -s "https://slack.com/api/conversations.history?channel=<channel_id>&limit=20" \
  -H "Authorization: Bearer $SLACK_TOKEN" | jq '.messages[] | {user, text, ts}'
```

### Read thread replies
```bash
curl -s "https://slack.com/api/conversations.replies?channel=<channel_id>&ts=<thread_ts>" \
  -H "Authorization: Bearer $SLACK_TOKEN" | jq '.messages[] | {user, text, ts}'
```

### Search messages
```bash
curl -s "https://slack.com/api/search.messages?query=<search_term>&count=10" \
  -H "Authorization: Bearer $SLACK_TOKEN" | jq '.messages.matches[] | {channel: .channel.name, text, username}'
```

### Get user info (resolve user IDs to names)
```bash
curl -s "https://slack.com/api/users.info?user=<user_id>" \
  -H "Authorization: Bearer $SLACK_TOKEN" | jq '.user | {name: .real_name, display: .profile.display_name}'
```

## Important
- **Read-only** — never post messages, react, or modify channels
- The bot token may only have access to channels it's been invited to
- Always resolve user IDs to names for readability
- Be mindful of sensitive content — summarize rather than dump raw messages
- Avoid reading DMs or private channels unless explicitly asked
- Slack rate limits: ~1 request/second for most endpoints
