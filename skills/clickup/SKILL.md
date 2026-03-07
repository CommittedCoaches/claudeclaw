---
name: clickup
description: Interact with ClickUp project management. Use when users ask about ClickUp tasks, spaces, lists, projects, sprints, task status, assignees, comments, or anything related to ClickUp. Trigger phrases include "ClickUp", "clickup task", "task list", "sprint", "project board", "create task", "task status", "assign task", "clickup comment".
---

# ClickUp — Project Management

Access ClickUp workspaces, spaces, lists, and tasks.

## Getting Credentials

```bash
source /opt/claudeclaw/shared-env.sh
# Uses $CLICKUP_API_KEY
```

All requests use the API key as a header:

```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/<endpoint>"
```

## Available Actions

### List workspaces (teams)
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team" | jq '.teams[] | {id, name}'
```

### List spaces in a workspace
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team/<team_id>/space" | jq '.spaces[] | {id, name}'
```

### List folders in a space
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/space/<space_id>/folder" | jq '.folders[] | {id, name}'
```

### List lists in a folder
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/folder/<folder_id>/list" | jq '.lists[] | {id, name}'
```

### List folderless lists in a space
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/space/<space_id>/list" | jq '.lists[] | {id, name}'
```

### Get tasks in a list
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/list/<list_id>/task?page=0" | jq '.tasks[] | {id, name, status: .status.status, assignees: [.assignees[].username]}'
```

### Get a specific task
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/task/<task_id>" | jq '{id, name, description, status: .status.status, assignees: [.assignees[].username], due_date, priority: .priority.priority}'
```

### Get task comments
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/task/<task_id>/comment" | jq '.comments[] | {id, comment_text, user: .user.username, date}'
```

### Create a task
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" -H "Content-Type: application/json" \
  "https://api.clickup.com/api/v2/list/<list_id>/task" \
  -d '{
    "name": "Task name",
    "description": "Task description",
    "status": "to do",
    "priority": 3
  }' | jq '{id, name, url}'
```

### Update a task
```bash
curl -s -X PUT -H "Authorization: $CLICKUP_API_KEY" -H "Content-Type: application/json" \
  "https://api.clickup.com/api/v2/task/<task_id>" \
  -d '{
    "status": "in progress"
  }' | jq '{id, name, status: .status.status}'
```

### Add a comment to a task
```bash
curl -s -H "Authorization: $CLICKUP_API_KEY" -H "Content-Type: application/json" \
  "https://api.clickup.com/api/v2/task/<task_id>/comment" \
  -d '{
    "comment_text": "Comment content"
  }' | jq .
```

## Navigation Pattern

To find tasks, navigate: workspace → space → folder/list → tasks:

```bash
# 1. Get workspace ID
TEAM_ID=$(curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team" | jq -r '.teams[0].id')

# 2. List spaces
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team/$TEAM_ID/space" | jq '.spaces[] | {id, name}'

# 3. Then drill into space → folder → list → tasks
```

## Important
- **Confirm with the user** before creating tasks or updating status
- Use pagination (`page=0`, `page=1`, ...) for large task lists
- Priority values: 1=urgent, 2=high, 3=normal, 4=low
- ClickUp API docs: https://clickup.com/api/
