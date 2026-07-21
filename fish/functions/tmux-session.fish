function tmux-session -d "Create or recreate tmux session based on current folder"
    set -l session_name (basename (pwd))
    
    # Kill existing session if it exists
    tmux has-session -t $session_name 2>/dev/null
    if test $status -eq 0
        tmux kill-session -t $session_name
    end
    
    # Create new detached session in current directory
    tmux new-session -d -s $session_name -c (pwd)
    
    # Attach or switch to session
    if test -n "$TMUX"
        tmux switch-client -t $session_name
    else
        tmux attach -t $session_name
    end
end
