function herdr-sessionizer -d "Select a project and focus/create its Herdr workspace"
    set -l search_paths ~/Code ~/RSR ~/Aldea
    set -l selected (command find $search_paths -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | fzf)
    if test -z "$selected"
        return
    end

    # resolve symlinks e normaliza case real do filesystem
    set -l real_path (realpath "$selected")

    set -l label (basename "$real_path" | string replace -ar '[^A-Za-z0-9_-]' '_' | string sub -l 64)

    set -l existing_id (herdr workspace list \
        | jq -r --arg path "$real_path" '.result.workspaces[]? | select(.tokens.path == $path) | .workspace_id' \
        | head -n1)

    if test -n "$existing_id"
        herdr workspace focus "$existing_id"
    else
        set -l created (herdr workspace create --cwd "$real_path" --label "$label" --focus)
        set -l new_id (echo $created | jq -r '.result.workspace.workspace_id')
        herdr workspace report-metadata "$new_id" --source herdr-sessionizer --token path="$real_path"
    end

    command herdr
end
