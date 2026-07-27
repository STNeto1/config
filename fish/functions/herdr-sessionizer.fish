function __herdr_sessionizer_ssh
    set -l target $argv[1]
    set -e argv[1]
    set -l remote_command (string join -- ' ' (string escape -- $argv))
    command ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" "$remote_command"
end

function __herdr_sessionizer_ensure_local
    set -l server_status (herdr status server 2>&1 | string collect)
    if string match -q '*status: running*' -- "$server_status"
        return 0
    end

    command nohup herdr server >/tmp/herdr-sessionizer.log 2>&1 </dev/null &
    disown

    for _attempt in (seq 1 50)
        sleep 0.1
        set server_status (herdr status server 2>&1 | string collect)
        if string match -q '*status: running*' -- "$server_status"
            return 0
        end
    end

    echo "Herdr server did not start. See /tmp/herdr-sessionizer.log." >&2
    return 1
end

function __herdr_sessionizer_ensure_remote -a target session
    if not __herdr_sessionizer_ssh "$target" true >/dev/null 2>&1
        echo "Unable to reach $target over SSH." >&2
        return 1
    end

    set -l server_status (__herdr_sessionizer_ssh "$target" herdr --session "$session" status 2>&1 | string collect)
    if string match -q '*status: running*' -- "$server_status"
        return 0
    end

    set -l escaped_session (string escape -- "$session")
    command ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" \
        "nohup herdr --session $escaped_session server >/tmp/herdr-$escaped_session.log 2>&1 </dev/null &" \
        >/dev/null 2>&1
    or begin
        echo "Failed to start Herdr session '$session' on $target." >&2
        return 1
    end

    for _attempt in (seq 1 20)
        sleep 0.1
        set server_status (__herdr_sessionizer_ssh "$target" herdr --session "$session" status 2>&1 | string collect)
        if string match -q '*status: running*' -- "$server_status"
            return 0
        end
    end

    echo "Herdr session '$session' did not start on $target." >&2
    return 1
end

function herdr-sessionizer -d "Select a local or remote project and focus/create its Herdr workspace"
    set -l mode local
    if test (count $argv) -gt 0
        switch $argv[1]
            case nixos remote --remote
                set mode remote
            case local
                set mode local
            case -h --help
                echo "usage: herdr-sessionizer [local|nixos]"
                echo
                echo "Remote overrides:"
                echo "  HERDR_REMOTE_TARGET        SSH target"
                echo "  HERDR_REMOTE_SESSION       Named Herdr session"
                echo "  HERDR_REMOTE_SEARCH_PATHS  Fish list of project roots"
                return
            case '*'
                echo "Unknown target '$argv[1]'. Expected local or nixos." >&2
                return 2
        end
    end

    if test "$mode" = local
        set -l search_paths ~/Code ~/RSR ~/Aldea
        set -l selected (command find $search_paths -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | fzf --prompt='Herdr local> ')
        if test -z "$selected"
            return
        end

        __herdr_sessionizer_ensure_local
        or return 1

        set -l real_path (realpath "$selected")
        set -l label (basename "$real_path" | string replace -ar '[^A-Za-z0-9_-]' '_' | string sub -l 64)
        set -l workspace_json (herdr workspace list)
        or return 1
        set -l existing_id (string join '' $workspace_json \
            | jq -r --arg path "$real_path" '.result.workspaces[]? | select(.tokens.path == $path) | .workspace_id' \
            | head -n1)

        if test -n "$existing_id"
            herdr workspace focus "$existing_id"
            or return 1
        else
            set -l created (herdr workspace create --cwd "$real_path" --label "$label" --focus)
            or return 1
            set -l new_id (string join '' $created | jq -r '.result.workspace.workspace_id // empty')
            if test -z "$new_id"
                echo "Failed to create a Herdr workspace for $real_path." >&2
                return 1
            end
            herdr workspace report-metadata "$new_id" --source herdr-sessionizer --token path="$real_path"
            or return 1
        end

        command herdr
        return
    end

    set -l remote_target germano@nixos.tail63cf69.ts.net
    set -q HERDR_REMOTE_TARGET; and set remote_target $HERDR_REMOTE_TARGET

    set -l remote_session agents
    set -q HERDR_REMOTE_SESSION; and set remote_session $HERDR_REMOTE_SESSION

    set -l remote_search_paths /home/germano/Code /home/germano/RSR /home/germano/Aldea
    set -q HERDR_REMOTE_SEARCH_PATHS; and set remote_search_paths $HERDR_REMOTE_SEARCH_PATHS

    __herdr_sessionizer_ensure_remote "$remote_target" "$remote_session"
    or return 1

    __herdr_sessionizer_ssh "$remote_target" mkdir -p $remote_search_paths
    or return 1

    set -l remote_find_command "find "(string join ' ' (string escape -- $remote_search_paths))" -mindepth 1 -maxdepth 1 -type d 2>/dev/null"
    set -l selected (command ssh -o BatchMode=yes -o ConnectTimeout=8 "$remote_target" "$remote_find_command" \
        | sort \
        | fzf --prompt="Herdr $remote_target> ")
    if test -z "$selected"
        echo "No project selected. Add repositories under "(string join ', ' $remote_search_paths)"." >&2
        return
    end

    set -l real_path (__herdr_sessionizer_ssh "$remote_target" realpath "$selected")
    or return 1
    set -l label (basename "$real_path" | string replace -ar '[^A-Za-z0-9_-]' '_' | string sub -l 64)

    set -l workspace_json (__herdr_sessionizer_ssh "$remote_target" herdr --session "$remote_session" workspace list)
    or return 1
    set -l existing_id (string join '' $workspace_json \
        | jq -r --arg path "$real_path" '.result.workspaces[]? | select(.tokens.path == $path) | .workspace_id' \
        | head -n1)

    if test -n "$existing_id"
        __herdr_sessionizer_ssh "$remote_target" herdr --session "$remote_session" workspace focus "$existing_id"
        or return 1
    else
        set -l created (__herdr_sessionizer_ssh "$remote_target" herdr --session "$remote_session" workspace create \
            --cwd "$real_path" --label "$label" --focus)
        or return 1
        set -l new_id (string join '' $created | jq -r '.result.workspace.workspace_id // empty')
        if test -z "$new_id"
            echo "Failed to create a remote Herdr workspace for $real_path." >&2
            return 1
        end
        __herdr_sessionizer_ssh "$remote_target" herdr --session "$remote_session" workspace report-metadata \
            "$new_id" --source herdr-sessionizer --token path="$real_path"
        or return 1
    end

    command herdr --remote "$remote_target" --session "$remote_session"
end
