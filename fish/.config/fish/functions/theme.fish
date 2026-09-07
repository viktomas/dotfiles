function theme --description "Flip light/dark for ghostty, zellij, fish and every open nvim"
    # Everything downstream follows the macOS appearance:
    #   ghostty  `theme = light:tomas-light,dark:tomas-dark` -> repaints open
    #            windows and emits a DEC 2031 colour-scheme notification
    #   zellij   relays 2031 into panes, swaps theme_dark/theme_light
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

    # Shells started before this setup landed (or any pane that missed the
    # notification) can be nudged by hand:
    #   zellij action toggle-theme
end
