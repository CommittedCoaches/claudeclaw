---
name: aws-cloudwatch
description: Read AWS CloudWatch logs. Use when users ask to check logs, view log groups, search logs, filter log events, tail logs, look at CloudWatch, debug from logs, find errors in logs, or query log insights. Trigger phrases include "check the logs", "cloudwatch logs", "log group", "filter logs", "search logs for", "what do the logs say", "error logs", "log insights query".
---

# AWS CloudWatch Log Reader

Read and search CloudWatch logs. Read-only access.

## Available Actions

1. **List log groups** — find available log groups
2. **Tail recent logs** — get the latest events from a log stream
3. **Filter/search logs** — search for patterns across a log group
4. **Log Insights query** — run CloudWatch Logs Insights queries

## How to Use

Use the AWS CLI (`aws logs` commands). The instance IAM role has read-only CloudWatch access.

### List log groups
```bash
aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table --region us-east-2
```

### Get recent log streams
```bash
aws logs describe-log-streams --log-group-name <group> --order-by LastEventTime --descending --limit 5 --region us-east-2
```

### Tail recent events
```bash
aws logs get-log-events --log-group-name <group> --log-stream-name <stream> --limit 50 --region us-east-2
```

### Filter/search logs
```bash
aws logs filter-log-events --log-group-name <group> --filter-pattern "<pattern>" --start-time <epoch-ms> --region us-east-2
```

### Log Insights query
```bash
aws logs start-query --log-group-name <group> \
  --start-time <epoch> --end-time <epoch> \
  --query-string 'fields @timestamp, @message | filter @message like /error/i | sort @timestamp desc | limit 20' \
  --region us-east-2
# Then get results:
aws logs get-query-results --query-id <id> --region us-east-2
```

## Important
- Region is always `us-east-2`
- Read-only — no creating or deleting log groups
- Use `--limit` to avoid overwhelming output
- Convert timestamps: `date -d @<epoch_seconds>` or use `--start-time` / `--end-time` with epoch milliseconds
