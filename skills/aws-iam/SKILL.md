---
name: aws-iam
description: Read AWS IAM permissions and suggest changes. Use when users ask about IAM roles, permissions, policies, who has access, what permissions a role has, or need to add permissions. Trigger phrases include "IAM permissions", "what access does", "check role permissions", "add permission", "who can access", "policy for", "list roles", "what policies".
---

# AWS IAM — Read-Only + Suggest Changes

Read IAM roles, users, and policies. Suggest CLI commands for permission changes (user confirms and runs manually).

## Available Actions

### List roles
```bash
aws iam list-roles --query 'Roles[*].{Name:RoleName,Arn:Arn}' --output table --region us-east-2
```

### Inspect a role's policies
```bash
# Inline policies
aws iam list-role-policies --role-name <role> --region us-east-2
aws iam get-role-policy --role-name <role> --policy-name <policy> --region us-east-2

# Attached managed policies
aws iam list-attached-role-policies --role-name <role> --region us-east-2
aws iam get-policy-version --policy-arn <arn> --version-id $(aws iam get-policy --policy-arn <arn> --query 'Policy.DefaultVersionId' --output text) --region us-east-2
```

### Inspect a user
```bash
aws iam get-user --user-name <user> --region us-east-2
aws iam list-user-policies --user-name <user> --region us-east-2
aws iam list-attached-user-policies --user-name <user> --region us-east-2
aws iam list-groups-for-user --user-name <user> --region us-east-2
```

## Suggesting Changes

When the user needs to add/modify permissions:
1. Read the current policies to understand what exists
2. Suggest the minimal IAM policy JSON needed
3. Provide the exact `aws iam` CLI command to apply it
4. **Never execute permission changes** — always present the command for the user to run manually

Example suggestion format:
```
To grant <role> access to <resource>, run:

aws iam put-role-policy --role-name <role> --policy-name <name> --policy-document '{...}'
```

## Important
- Read-only — this skill cannot modify IAM
- Always suggest least-privilege policies
- Include both the policy JSON and the CLI command
