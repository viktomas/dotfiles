#!/usr/bin/env bash
# Mark a single GitLab TODO as done
# Usage: mark-todo-done.sh <todo_id>
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: mark-todo-done.sh <todo_id>" >&2
  exit 1
fi

TODO_ID="$1"
BASE_URL="https://gitlab.com/api/v4"

curl -sf --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "${BASE_URL}/todos/${TODO_ID}/mark_as_done" | python3 -c "
import json, sys
todo = json.load(sys.stdin)
if isinstance(todo, dict) and 'message' in todo:
    print('Error:', todo['message'], file=sys.stderr); sys.exit(1)
print(f'Marked TODO {todo.get(\"id\")} as done: {(todo.get(\"target\") or {}).get(\"title\", \"?\")}')
"
