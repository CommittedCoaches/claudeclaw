---
name: database-query
description: Query databases read-only. Use when users ask to query a database, check data, look up records, run SQL, check the scoring DB, billing DB, data warehouse, C100, CommittedCoaches DB, or any database query. Trigger phrases include "query the database", "check the DB", "SQL query", "look up in scoring", "billing data", "data warehouse", "run a query", "what's in the database", "SELECT from".
---

# Database Query — Read-Only

Query organization databases with read-only access. Credentials are stored in AWS Secrets Manager.

## Available Databases

| Database | Secret Name | Type |
|---|---|---|
| Scoring DB | `RODatabaseAccess-scoring` | PostgreSQL |
| Billing DB | `RODatabaseAccess-billing` | PostgreSQL |
| C100 | `RODatabaseAccess-C100` | PostgreSQL |
| C100K | `RODatabaseAccess-C100K` | PostgreSQL |
| CommittedCoaches | `RODatabaseAccess-CommittedCoaches` | PostgreSQL |
| Airbytes | `RODatabaseAccess-airbytes` | PostgreSQL |
| Data Warehouse | `DataWarehouseRW` | Redshift |

## How to Use

### 1. Get credentials from Secrets Manager
```bash
CREDS=$(aws secretsmanager get-secret-value --secret-id <secret-name> --query SecretString --output text --region us-east-2)
DB_HOST=$(echo $CREDS | jq -r '.host')
DB_PORT=$(echo $CREDS | jq -r '.port')
DB_USER=$(echo $CREDS | jq -r '.username')
DB_PASS=$(echo $CREDS | jq -r '.password')
DB_NAME=$(echo $CREDS | jq -r '.dbname // .database // .dbClusterIdentifier')
```

### 2. Run query with psql
```bash
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "<SQL>"
```

Or for Redshift (Data Warehouse):
```bash
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "<SQL>"
```

### 3. Useful meta-queries
```sql
-- List tables
SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY table_schema, table_name;

-- Describe a table
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = '<table>' ORDER BY ordinal_position;

-- Row count
SELECT count(*) FROM <table>;
```

## Important
- **READ-ONLY** — only SELECT queries. Never INSERT, UPDATE, DELETE, DROP, ALTER, or TRUNCATE
- Always use LIMIT to avoid pulling too much data (default to LIMIT 100)
- Never output raw credentials — use them in-memory only
- For large result sets, summarize rather than dumping all rows
- If `psql` is not installed, install it: `sudo apt-get install -y postgresql-client`
- The secret JSON structure may vary — inspect it first with `echo $CREDS | jq .` to see available fields
