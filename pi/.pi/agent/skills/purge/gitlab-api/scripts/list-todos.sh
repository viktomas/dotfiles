#!/usr/bin/env bash
# List GitLab TODOs for the authenticated user
# Usage: list-todos.sh [--state pending|done] [--action ACTION] [--type TYPE] [--per-page N]
set -euo pipefail

BASE_URL="https://gitlab.com/api/v4"
STATE="pending"
ACTION=""
TYPE=""
PER_PAGE="50"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)    STATE="$2"; shift 2 ;;
    --action)   ACTION="$2"; shift 2 ;;
    --type)     TYPE="$2"; shift 2 ;;
    --per-page) PER_PAGE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PARAMS="state=${STATE}&per_page=${PER_PAGE}"
[[ -n "$ACTION" ]] && PARAMS="${PARAMS}&action=${ACTION}"
[[ -n "$TYPE" ]] && PARAMS="${PARAMS}&type=${TYPE}"

curl -sf --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "${BASE_URL}/todos?${PARAMS}" | python3 -c "
import json, sys
todos = json.load(sys.stdin)
if isinstance(todos, dict) and 'message' in todos:
    print('Error:', todos['message'], file=sys.stderr); sys.exit(1)
print(f'Total TODOs: {len(todos)}\n')
for t in todos:
    action = t.get('action_name', '?')
    target_type = t.get('target_type', '?')
    title = (t.get('target') or {}).get('title', '?')
    proj = (t.get('project') or {}).get('path_with_namespace', '?')
    author = (t.get('author') or {}).get('name', '?')
    date = t.get('created_at', '?')[:10]
    url = (t.get('target') or {}).get('web_url', '')
    todo_id = t.get('id', '?')
    print(f'[{action}] {target_type} (id:{todo_id}): {title}')
    print(f'  Project: {proj} | By: {author} | Date: {date}')
    if url: print(f'  URL: {url}')
    print()
"
