# THIS IS DUPLICATTED
set -g WATCH_EXTENSION_PATH /Users/tomas/workspace/gl/gitlab-vscode-extension
set -g WATCH_LS_PATH /Users/tomas/workspace/gl/gitlab-lsp

function ,watch
    # Check arguments
    if test (count $argv) -ne 2
        echo "Usage: ,watch <extension_folder> <ls_folder>"
        return 1
    end

    set extension_path "$WATCH_EXTENSION_PATH/$argv[1]"
    set ls_path "$WATCH_LS_PATH/$argv[2]"

    # Validate folders exist
    if not test -d "$extension_path"
        echo "Error: Extension folder '$argv[1]' not found"
        return 1
    end

    if not test -d "$ls_path"
        echo "Error: LS folder '$argv[2]' not found"
        return 1
    end

    # Create temporary layout file
    set layout_file (mktemp).kdl

    # Generate Zellij layout
    echo "layout {
    pane size=1 borderless=true {
        plugin location=\"zellij:tab-bar\"
    }
    pane split_direction=\"vertical\" {
        pane size=\"50%\" {
            command \"bash\"
            args \"-c\" \"cd '$extension_path' && npm run watch:desktop\"
        }
        pane size=\"50%\" {
            command \"bash\"
            args \"-c\" \"cd '$ls_path' && npm run watch -- --editor=vscode --editor-path='$extension_path'\"
        }
    }
    pane size=2 borderless=true {
        plugin location=\"zellij:status-bar\"
    }
}" >$layout_file

    # Start Zellij session
    set session_name "worktree-watch-"(date +%s)
    zellij --new-session-with-layout $layout_file --session $session_name

    # Clean up
    rm -f $layout_file
end
