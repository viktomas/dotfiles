#!/bin/bash
# Trigger a Duo remote flow by mentioning a flow service account on an issue, wait for the
# workload job, save its log and print the agent's reply.
# Usage: dap-mention.sh <a|b|c> <project-path> <issue-iid> <service-account> <prompt...>
#   e.g. dap-mention.sh a gitlab-duo/test 1 duo-developer-gitlab-duo "Reply OK without tools"
# Output: job id/status, path of the saved (ANSI-stripped) log /tmp/dap-job-<x>-<id>.txt,
#         and the newest two notes on the issue.
set -uo pipefail
source "$(dirname "$0")/caproni-env.sh" "$1" || exit 1
PROJECT=$(printf %s "$2" | jq -sRr @uri); ISSUE=$3; SA=$4; shift 4; PROMPT="$*"
X=$(echo "$CAPRONI_INSTANCE" | tr a-z A-Z); TOKEN_VAR="CAPRONI_${X}_TOKEN"; URL_VAR="CAPRONI_${X}_URL"
H="PRIVATE-TOKEN: ${!TOKEN_VAR}"; U="${!URL_VAR}/api/v4"

last_job() { curl -s -H "$H" "$U/projects/$PROJECT/jobs?per_page=1" | jq -r 'if type=="array" then (.[0].id // 0) else "ERR" end'; }
before=$(last_job); [ "$before" = ERR ] && { echo "API not answering (is edit mode up?)"; exit 1; }
note=$(curl -s -X POST -H "$H" "$U/projects/$PROJECT/issues/$ISSUE/notes" --data-urlencode "body=@$SA $PROMPT" | jq -r '.id // empty')
[ -z "$note" ] && { echo "posting the note failed"; exit 1; }
echo "note=$note"
for _ in $(seq 1 36); do J=$(last_job); [ "$J" != "$before" ] && [ "$J" != ERR ] && break; sleep 5; done
[ "$J" = "$before" ] && { echo "no workload job appeared - check the latest notes:"; curl -s -H "$H" "$U/projects/$PROJECT/issues/$ISSUE/notes?sort=desc&per_page=2" | jq -r '.[]|"\(.author.username): \(.body[0:300])"'; exit 1; }
for _ in $(seq 1 80); do
  s=$(curl -s -H "$H" "$U/projects/$PROJECT/jobs/$J" | jq -r .status)
  case $s in created|pending|running|preparing|waiting_for_resource) sleep 15 ;; *) break ;; esac
done
LOG="/tmp/dap-job-$CAPRONI_INSTANCE-$J.txt"
curl -s -H "$H" "$U/projects/$PROJECT/jobs/$J/trace" | sed $'s/\e\\[[0-9;]*[a-zA-Z]//g' > "$LOG"
echo "job=$J status=$s log=$LOG"
sleep 3; curl -s -H "$H" "$U/projects/$PROJECT/issues/$ISSUE/notes?sort=desc&per_page=2" | jq -r '.[]|"--- \(.author.username):\n\(.body[0:600])"'
