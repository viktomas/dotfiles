source ~/.secrets/secrets
source ~/.secrets/gdk
set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc
# Shared Turborepo cache across git worktrees (each worktree has its own
# node_modules/.turbo, so without this every fresh worktree rebuilds from scratch)
# set -gx TURBO_CACHE_DIR ~/.cache/turbo
if status is-interactive
    abbr --add fd fd --hidden
    fish_vi_key_bindings

    # Tomorrow Night / Tomorrow, one theme file with a [dark] and a [light]
    # section (themes/tomas.theme). fish re-applies the matching one whenever
    # $fish_terminal_color_theme changes, so a running shell recolors itself
    # when ghostty flips light/dark. `theme save` would break that -- see the
    # comment at the top of the theme file, and nvim/THEME.md.
    fish_config theme choose tomas

    function fish_user_key_bindings
        bind --mode insert \cr fzf_history_search
        bind --mode insert \cf forward-char
        bind --mode default gcc "fish_commandline_prepend '#'"
        bind --mode insert \c_ "fish_commandline_prepend '#'"
        bind --mode insert ctrl-alt-l fzf_git_log
        bind --mode insert ctrl-alt-p fzf_process_search
        bind --mode insert ctrl-alt-f fzf_file
        bind --mode insert \cx zummoner
    end

    zoxide init fish --no-cmd | source
    mise activate fish | source
    direnv hook fish | source

    # --- zellij tab naming -------------------------------------------------
    # Tab name = "base (activity)":
    #   activity = the command currently running (cleared when it exits)
    #   base     = manual override ".label" (authoritative), else the folder
    #              relative to the task cwd (empty when sitting in the task cwd)
    set -g __zellij_ignore_cmds ls ll la l cd z j cat bat echo pwd clear which type man

    function __zellij_task_cwd
        # cache the task working dir for this shell (it doesn't change)
        if not set -q __zellij_task_cwd_cache
            if set -q TASK_ID; and test -n "$TASK_ID"
                set -g __zellij_task_cwd_cache (task get cwd 2>/dev/null)
            else
                set -g __zellij_task_cwd_cache ''
            end
        end
        echo -- $__zellij_task_cwd_cache
    end

    function __zellij_tab_render --argument-names running
        set -q ZELLIJ; or return
        set -l current (command zellij action current-tab-info 2>/dev/null | string match -rg '^name: (.*)')

        set -l base
        if string match -q '.*' -- "$current"
            # manual name is authoritative: keep it, drop any activity suffix
            set base (string replace -r ' \(.*\)$' '' -- "$current")
        else
            set -l taskcwd (__zellij_task_cwd)
            if test -n "$taskcwd"; and test "$PWD" = "$taskcwd"
                set base ''
            else
                # last two path components, e.g. project/worktree
                set -l parts (string match -v '' -- (string split / -- $PWD))
                set -l n (count $parts)
                if test $n -ge 2
                    set -l parent $parts[-2]
                    # keep tabs short: truncate an over-long parent name
                    if test (string length -- $parent) -gt 16
                        set parent (string sub -l 15 -- $parent)"…"
                    end
                    set base "$parent/$parts[-1]"
                else if test $n -eq 1
                    set base $parts[-1]
                end
            end
            # leading '.' is reserved for manual names, so strip it from auto bases
            set base (string replace -r '^\.+' '' -- "$base")
        end

        set -l name
        if test -n "$base"; and test -n "$running"
            set name "$base ($running)"
        else if test -n "$base"
            set name "$base"
        else if test -n "$running"
            set name "$running"
        end

        if test -z "$name"
            command zellij action undo-rename-tab >/dev/null 2>&1
        else
            command zellij action rename-tab "$name" >/dev/null 2>&1
        end
    end

    function __zellij_tab_preexec --on-event fish_preexec
        set -q ZELLIJ; or return
        set -l cmd (string match -rg '^\s*(\S+)' -- $argv[1])
        if contains -- "$cmd" $__zellij_ignore_cmds
            __zellij_tab_render
        else
            __zellij_tab_render "$cmd"
        end
    end

    function __zellij_tab_postexec --on-event fish_postexec
        __zellij_tab_render
    end

    # initial render so a freshly opened tab picks up its folder/idle state
    __zellij_tab_render

end

# Added by GDK bootstrap
/opt/homebrew/bin/mise activate fish | source

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tomas/google-cloud-sdk/path.fish.inc' ]
    . '/Users/tomas/google-cloud-sdk/path.fish.inc'
end
