function herdr-sessionizer -d "Select a project and launch its Herdr session"
    set -l search_paths ~/Code ~/RSR ~/Code/ALDEA

    set -l selected (command find $search_paths -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | fzf)
    if test -z "$selected"
        return
    end

    set -l session_name (basename "$selected" | string replace -ar '[^A-Za-z0-9_-]' '_' | string sub -l 64)

    pushd "$selected" >/dev/null
    command herdr --session "$session_name"
    set -l herdr_status $status
    popd >/dev/null

    return $herdr_status
end
