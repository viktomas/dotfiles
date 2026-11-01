function fzf_file --description "fzf-pick a file from the current repo and insert its path at the cursor"
    set -l initial_query (commandline --current-token)
    set -l files
    set -l root (git rev-parse --show-toplevel 2>/dev/null)

    if test -n "$root"
        # whole repo: tracked + untracked (ignored excluded), repo-root-relative
        set files (git -C $root ls-files --cached --others --exclude-standard)
    else
        # not a repo: everything under the cwd
        set files (fd --hidden)
    end

    string join \n -- $files | fzf \
        --query "$initial_query" \
        --highlight-line \
        --tiebreak=index \
        | read -l file

    if test -n "$file"
        if test -n "$root"
            # candidates were repo-root-relative; convert the pick to a path
            # relative to $PWD so the inserted token works from any subdir.
            # (macOS realpath has no --relative-to, so do it by hand.)
            set -l cwd_parts (string split / -- $PWD | string match -v '')
            set -l abs_parts (string split / -- $root/$file | string match -v '')
            set -l i 1
            while test $i -le (count $cwd_parts); and test $i -le (count $abs_parts); and test "$cwd_parts[$i]" = "$abs_parts[$i]"
                set i (math $i + 1)
            end
            set -l rel
            set -l n_ups (math (count $cwd_parts) - $i + 1)
            if test $n_ups -gt 0
                for j in (seq $n_ups)
                    set -a rel ..
                end
            end
            set -a rel $abs_parts[$i..-1]
            set file (string join / -- $rel)
        end
        commandline -i -- (string escape -- $file)
    end
end
