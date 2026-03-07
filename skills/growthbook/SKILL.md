---
name: growthbook
description: Interact with GrowthBook feature flags and experiments. Use when users ask about feature flags, experiments, GrowthBook, feature toggles, A/B tests, or flag status. Trigger phrases include "GrowthBook", "feature flag", "feature toggle", "experiment", "A/B test", "flag status", "enable feature", "disable feature", "check flag".
---

# GrowthBook — Full Access

Manage feature flags and experiments via the GrowthBook API.

## Getting Credentials

```bash
GB_API_KEY=$(aws secretsmanager get-secret-value --secret-id /distribution/config/GROWTHBOOK_API_KEY --query SecretString --output text --region us-east-2)
GB_SDK_KEY=$(aws secretsmanager get-secret-value --secret-id GROWTHBOOK_SDK_KEY --query SecretString --output text --region us-east-2)
```

The API key may be a JSON object — inspect first:
```bash
echo $GB_API_KEY | jq . 2>/dev/null || echo "$GB_API_KEY"
```

## API Usage

GrowthBook API base URL (check your instance — may be self-hosted or cloud):

```bash
GB_BASE="https://api.growthbook.io"  # or your self-hosted URL
```

### List features
```bash
curl -s "$GB_BASE/api/v1/features" \
  -H "Authorization: Bearer $GB_API_KEY" | jq '.features[] | {id, defaultValue, description}'
```

### Get a specific feature
```bash
curl -s "$GB_BASE/api/v1/features/<feature_key>" \
  -H "Authorization: Bearer $GB_API_KEY" | jq .
```

### Toggle a feature flag
```bash
curl -s -X POST "$GB_BASE/api/v1/features/<feature_key>/toggle" \
  -H "Authorization: Bearer $GB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"environment":"production","state":true}' | jq .
```

### List experiments
```bash
curl -s "$GB_BASE/api/v1/experiments" \
  -H "Authorization: Bearer $GB_API_KEY" | jq '.experiments[] | {id, name, status}'
```

### Get experiment results
```bash
curl -s "$GB_BASE/api/v1/experiments/<experiment_id>/results" \
  -H "Authorization: Bearer $GB_API_KEY" | jq .
```

## Important
- Full access — can read and modify feature flags and experiments
- Always confirm with user before toggling flags in production
- The SDK key is for client-side evaluation, the API key is for management
- Inspect the secret format first — structure varies
