---
name: aws-airflow
description: Interact with AWS MWAA (Managed Airflow). Use when users ask to trigger a DAG, check DAG status, list DAGs, run an Airflow pipeline, check Airflow, trigger a data pipeline, rerun a task, or view DAG run history. Trigger phrases include "trigger the DAG", "run airflow", "airflow status", "DAG run", "rerun the pipeline", "check airflow", "list DAGs", "trigger data pipeline".
---

# AWS Airflow (MWAA) — Read & Trigger

Interact with AWS Managed Workflows for Apache Airflow. Can list DAGs, check status, and trigger runs.

## How to Use

First, get a CLI token to interact with the Airflow API:

### Get Airflow environment info
```bash
aws mwaa list-environments --region us-east-2
aws mwaa get-environment --name <env-name> --region us-east-2
```

### Get a CLI token
```bash
CLI_TOKEN=$(aws mwaa create-cli-token --name <env-name> --region us-east-2 --query 'CliToken' --output text)
WEBSERVER=$(aws mwaa get-environment --name <env-name> --region us-east-2 --query 'Environment.WebserverUrl' --output text)
```

### List DAGs
```bash
curl -s "https://$WEBSERVER/aws_mwaa/cli" \
  -H "Authorization: Bearer $CLI_TOKEN" \
  -H "Content-Type: text/plain" \
  -d "dags list" | jq -r '.output' | base64 -d
```

### Trigger a DAG run
```bash
curl -s "https://$WEBSERVER/aws_mwaa/cli" \
  -H "Authorization: Bearer $CLI_TOKEN" \
  -H "Content-Type: text/plain" \
  -d "dags trigger <dag_id>"  | jq -r '.output' | base64 -d
```

### Check DAG run status
```bash
curl -s "https://$WEBSERVER/aws_mwaa/cli" \
  -H "Authorization: Bearer $CLI_TOKEN" \
  -H "Content-Type: text/plain" \
  -d "dags list-runs -d <dag_id> -o table" | jq -r '.output' | base64 -d
```

### Check task status for a run
```bash
curl -s "https://$WEBSERVER/aws_mwaa/cli" \
  -H "Authorization: Bearer $CLI_TOKEN" \
  -H "Content-Type: text/plain" \
  -d "tasks list <dag_id>" | jq -r '.output' | base64 -d
```

## Important
- Region is always `us-east-2`
- CLI tokens expire after 60 seconds — get a fresh one before each command
- Always confirm with the user before triggering a DAG run
- DAG triggers are idempotent — triggering twice creates two runs
