function git --wraps=git --description 'sets a special behaviour for git wta and wtu'
    if test "$argv[1]" = wta
        if string match -q '*gitlab.com*' -- "$argv[2]"
            # MR URL mode: create/find worktree for the MR branch
            set -l output (~/bin/git-mr-worktree.sh "$argv[2]")
            or return 1
            set -l worktree_path $output[1]
            cd $worktree_path
            echo "✓ Changed to worktree: $worktree_path" >&2
            # Machine-readable: bare worktree path on the last stdout line.
            echo $worktree_path
        else
            # New-worktree mode.
            set -l name $argv[2]
            # Folder name is the branch slug with '/' -> '-' so the worktree
            # layout stays flat (matches MR mode).
            set -l folder (string replace -a / - -- $name)
            command git fetch origin
            set -l worktree_path
            if command git show-ref --verify --quiet "refs/heads/$name"
                or command git show-ref --verify --quiet "refs/remotes/origin/$name"
                # Branch already exists: check it out in a new worktree as-is
                set worktree_path (~/bin/git-wa.sh $folder $name)
                or return 1
            else
                # New branch: prefix with tv/YYYY-MM and base on origin/main
                set -l date_prefix (date +%Y-%m)
                set -l branch "tv/$date_prefix/$name"
                set worktree_path (~/bin/git-wa.sh $folder -b $branch --no-track origin/main)
                or return 1
            end
            cd $worktree_path
            echo "✓ Changed to worktree: $worktree_path" >&2
            # Machine-readable: bare worktree path on the last stdout line.
            echo $worktree_path
        end
    else if test "$argv[1]" = wtu
        # Update the local main branch worktree without changing cwd
        set -l git_common (command git rev-parse --git-common-dir 2>/dev/null)
        or begin
            echo "error: not in a git repository" >&2
            return 1
        end
        set -l repo_root (string replace -- '/.bare' '' (realpath $git_common))

        # Detect main branch name
        set -l main_branch
        if command git show-ref --verify --quiet refs/remotes/origin/main
            set main_branch main
        else if command git show-ref --verify --quiet refs/remotes/origin/master
            set main_branch master
        else
            echo "error: could not find main or master branch on origin" >&2
            return 1
        end

        # Find the worktree path for the main branch
        set -l wt_path ""
        set -l current_wt ""
        set -l current_branch ""
        for line in (command git worktree list --porcelain)
            if string match -q 'worktree *' -- $line
                set current_wt (string replace 'worktree ' '' -- $line)
            else if string match -q 'branch *' -- $line
                set current_branch (string replace 'branch refs/heads/' '' -- $line)
                if test "$current_branch" = "$main_branch"
                    set wt_path $current_wt
                end
            end
        end

        if test -z "$wt_path"
            echo "error: no worktree found for branch '$main_branch'" >&2
            return 1
        end

        echo "Fetching origin/$main_branch..."
        command git fetch origin $main_branch
        or return 1

        echo "Updating $wt_path..."
        command git -C $wt_path merge --ff-only origin/$main_branch
        or begin
            echo "error: could not fast-forward $main_branch (has local commits?)" >&2
            return 1
        end

        echo "✓ $main_branch is up to date"
    else
        command git $argv
    end
end
