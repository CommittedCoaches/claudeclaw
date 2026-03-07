---
name: ghl
description: Interact with GoHighLevel (GHL) API. Use when users ask about GHL contacts, calendars, appointments, opportunities, GHL data, GHL API, or anything related to GoHighLevel. Trigger phrases include "GHL", "GoHighLevel", "GHL contact", "GHL calendar", "GHL appointment", "GHL opportunity", "GHL API", "check GHL", "GHL data".
---

# GoHighLevel (GHL) — Read + Write (with confirmation)

Access GHL API endpoints. Read freely, write operations require user confirmation.

## Getting Credentials

GHL uses OAuth tokens stored in Secrets Manager:

```bash
GHL_CREDS=$(aws secretsmanager get-secret-value --secret-id GHL_OAUTH --query SecretString --output text --region us-east-2)
GHL_TOKEN=$(echo $GHL_CREDS | jq -r '.access_token // .token')
GHL_LOCATION=$(echo $GHL_CREDS | jq -r '.locationId // .location_id // empty')
```

If there's an OAuth proxy:
```bash
PROXY_CREDS=$(aws secretsmanager get-secret-value --secret-id ghl-oauth-proxy/credentials --query SecretString --output text --region us-east-2)
```

## Read Operations (no confirmation needed)

### List contacts
```bash
curl -s "https://services.leadconnectorhq.com/contacts/?locationId=$GHL_LOCATION&limit=20" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" | jq '.contacts[] | {id, firstName, lastName, email}'
```

### Get a contact
```bash
curl -s "https://services.leadconnectorhq.com/contacts/<contact_id>" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" | jq .
```

### List calendars
```bash
curl -s "https://services.leadconnectorhq.com/calendars/?locationId=$GHL_LOCATION" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" | jq '.calendars[] | {id, name}'
```

### List appointments
```bash
curl -s "https://services.leadconnectorhq.com/calendars/events?locationId=$GHL_LOCATION&startTime=<ISO>&endTime=<ISO>" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" | jq '.events[] | {id, title, startTime, status}'
```

### List opportunities/pipelines
```bash
curl -s "https://services.leadconnectorhq.com/opportunities/pipelines?locationId=$GHL_LOCATION" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" | jq .
```

## Write Operations (ALWAYS confirm with user first)

### Create/update contact
```bash
curl -s -X POST "https://services.leadconnectorhq.com/contacts/" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{"locationId":"'$GHL_LOCATION'","firstName":"...","lastName":"...","email":"..."}'
```

### Update appointment
```bash
curl -s -X PUT "https://services.leadconnectorhq.com/calendars/events/<event_id>" \
  -H "Authorization: Bearer $GHL_TOKEN" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{"status":"confirmed"}'
```

## Important
- **Read endpoints**: use freely
- **Write endpoints**: ALWAYS show the user what you're about to do and get explicit confirmation before executing
- OAuth tokens may expire — if you get a 401, report it to the user
- GHL API docs: https://highlevel.stoplight.io/docs/integrations
- Inspect the secret structure first: `echo $GHL_CREDS | jq .`
