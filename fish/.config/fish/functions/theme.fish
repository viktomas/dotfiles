function theme --description "Flip light/dark for ghostty, zellij, fish and every open nvim"
    # Everything downstream follows the macOS appearance:
    #   ghostty  `theme = light:tomas-light,dark:tomas-dark` -> repaints open
    #            windows and emits a DEC 2031 colour-scheme notification
    #   zellij   relays 2031 into panes, but does NOT switch its own UI
    #            (bar/frames) theme, so we push set-light/dark-theme to every
    #            live session below
    #   fish     re-applies themes/tomas.theme's [light]/[dark] section
    #   nvim     re-queries OSC 11, sets 'background', theme.lua follows it
    # See nvim/THEME.md §2.2.
    set -l mode $argv[1]
    test -z "$mode"; and set mode toggle

    switch $mode
        case light
            osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to false'
        case dark
            osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
        case toggle
            osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
        case '*'
            echo "usage: theme [light|dark|toggle]" >&2
            return 1
    end

    # zellij's own UI (status/compact bar, pane frames) is drawn by zellij, not
    # by the terminal, and it ignores the DEC 2031 notification it forwards to
    # panes. Push the new mode to every running session explicitly.
    if command -q zellij
        set -l target dark
        test "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = Dark; or set target light

        for line in (zellij list-sessions -n 2>/dev/null | string match -v '*EXITED*')
            set -l session (string split -f1 ' ' -- $line)
            zellij --session $session action set-$target-theme 2>/dev/null
        end
    end

    # Shells started before this setup landed (or any pane that missed the
    # notification) can be nudged by hand:
    #   zellij action toggle-theme
end
