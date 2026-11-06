function mr --description 'Pick an MR and check out its branch locally'
    # Run the Go picker binary — JSON output on stdout, progress on stderr
    set -l json_output (command mr 2>/dev/tty)
    or return 1

    # Check if output is empty (user cancelled)
    if test -z "$json_output"
        return 0
    end

    set -l json_str (string join \n $json_output)

    # Check if local_dir was resolved
    set -l local_dir (echo $json_str | jq -r '.local_dir // empty')
    if test -z "$local_dir"
        set -l project (echo $json_str | jq -r '.mr.project_path')
        echo "❌ No local directory found for project: $project"
        echo "   Configure scan_dirs in ~/.config/mr/config.yaml or add to G_FOLDER_ALIASES"
        return 1
    end

    set -l mr_url (echo $json_str | jq -r '.mr.web_url')
    set -l section (echo $json_str | jq -r '.mr.section // empty')

    # Reviewing: open the review task, or start a review cycle when there is none
    # (same path as review-autopilot.sh; the TTY keeps checkout interactive).
    if test "$section" = reviewing
        set -l task_json (task list --json 2>/dev/null)
        if test $status -ne 0
            echo "❌ task list failed — cannot look up the review task"
            return 1
        end
        set -l review_task (echo $task_json | jq -r --arg url "$mr_url" \
            '[.[] | select(.mr_url == $url)] | first | .id // empty')
        if test -z "$review_task"
            echo "🔍 Starting a review for: "(echo $json_str | jq -r '.mr.title')
            set -l out (~/workspace/gl/work/scripts/review-mr.sh --launch "$mr_url")
            set -l rc $status
            printf '%s\n' $out
            set -l new_id (string match -rg '✓ Review started: (\S+)' -- $out)
            if test $rc -eq 0 -a -n "$new_id"
                echo "🔀 Switching to task: $new_id"
                task switch $new_id
                return 0
            end
            echo "⚠️  review-mr.sh --launch failed — falling back to plain checkout"
        end
    end

    # Run checkout script — path on stdout, progress on stderr
    set -l checkout_path (echo $json_str | ~/bin/mr-checkout.sh 2>/dev/tty)
    or return 1

    if test -z "$checkout_path"
        echo "❌ Checkout script returned no path"
        return 1
    end

    # Check for an existing task for THIS MR.
    #
    # mr_url is the identity of an MR task; cwd is NOT. For a non-bare repo
    # mr-checkout.sh returns the repo root for every MR, so all MRs of that project
    # share one cwd — matching on cwd there hijacks an unrelated task.
    # Only a bare-repo worktree path is branch-specific enough to identify an MR.
    set -l is_bare (echo $json_str | jq -r '.is_bare // false')
    set -l task_json (task list --json 2>/dev/null)
    if test -n "$task_json"
        # 1. Exact mr_url match — the only reliable identity.
        # 2. Fallback (bare repos only, for tasks predating mr_url): cwd match,
        #    skipping tasks already bound to a different MR, newest touched first.
        set -l task_id (echo $task_json | jq -r \
            --arg path "$checkout_path" --arg url "$mr_url" --arg bare "$is_bare" '
            def pick: sort_by(.touched // .created) | reverse | (first | .id) // "";
            ([.[] | select(.mr_url == $url)] | pick) as $byUrl
            | if $byUrl != "" then $byUrl
              elif $bare == "true" then
                [.[] | select(.cwd == $path and (.mr_url // "") == "")] | pick
              else ""
              end')

        if test -n "$task_id"
            set -l task_status (echo $task_json | jq -r --arg id "$task_id" \
                '[.[] | select(.id == $id)] | first | .status // empty')

            if test "$task_status" = done
                echo "🔄 Reopening done task: $task_id"
                task set $task_id status doing
            end

            # Bind the task to this MR so future runs match on identity, not cwd
            task set $task_id mr_url "$mr_url" >/dev/null

            echo "🔀 Switching to task: $task_id"
            task switch $task_id
            return 0
        end
    end

    # No existing task — create one
    set -l mr_title (echo $json_str | jq -r '.mr.title')
    set -l mr_iid (echo $json_str | jq -r '.mr.iid')
    set -l project_name (echo $json_str | jq -r '.mr.project_path | split("/") | last')

    echo "📝 Creating task for: $mr_title"
    set -l new_task_json (task new "$project_name: $mr_title" --cwd "$checkout_path" --category review --json 2>/dev/null)
    if test $status -eq 0
        set -l new_task_id (echo $new_task_json | jq -r '.id // empty')
        if test -n "$new_task_id"
            # Store MR URL in task metadata
            task set $new_task_id mr_url "$mr_url"
            echo "🔀 Switching to task: $new_task_id"
            task switch $new_task_id
            return 0
        end
    end

    # Fallback: just cd
    echo "📂 Changing to: $checkout_path"
    cd $checkout_path
end
