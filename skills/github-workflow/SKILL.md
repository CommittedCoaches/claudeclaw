---
name: github-workflow
description: GitHub workflow operations — PRs, CI, comments, deployments. Use when users ask to create a PR, check CI status, view GitHub Actions, see PR comments, resolve review comments, re-trigger a deployment, check build logs, or re-run a failed workflow. Trigger phrases include "create PR", "check CI", "GitHub Actions", "PR comments", "resolve comments", "redeploy", "re-run workflow", "build failed", "deployment error", "check the pipeline".
---

# GitHub Workflow

Create PRs, manage comments, view CI, and re-trigger deployments via `gh` CLI.

## Pull Requests

### Create a PR
```bash
gh pr create --title "<title>" --body "<body>" --base main
```

### List open PRs
```bash
gh pr list
```

### View PR details and comments
```bash
gh pr view <number>
gh pr view <number> --comments
```

### View review comments
```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments --jq '.[] | "\(.path):\(.line) - \(.body)"'
```

### Resolve review comments
Read the comment, make the code change, commit, and push. The comment resolves when the PR is updated.

## CI / GitHub Actions

### Check workflow runs
```bash
gh run list --limit 10
gh run view <run-id>
```

### View failed job logs
```bash
gh run view <run-id> --log-failed
```

### Re-run a failed workflow
```bash
gh run rerun <run-id> --failed
```

### Watch a running workflow
```bash
gh run watch <run-id>
```

## Deployments

After a PR is manually merged, if deployment fails (linter errors, variable name bugs, etc.):

1. Check the failed run: `gh run view <run-id> --log-failed`
2. Fix the issue in code
3. Commit and push the fix
4. The deployment workflow re-triggers automatically on push to main

If a workflow needs manual re-trigger:
```bash
gh workflow run <workflow-name> --ref main
```

## Important
- **Never merge PRs** — only create them. Merging is manual.
- Can re-trigger deployments after manual merge
- Always set the correct repo context: `gh repo set-default <owner>/<repo>` if needed
- Use `--repo <owner>/<repo>` flag when working across multiple repos
