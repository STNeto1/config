if status is-interactive

    function ls
        eza --icons --group-directories-first $argv
    end

    function cd
        if test (count $argv) -eq 0
            builtin cd ~
        else
            z $argv
        end
    end

    function fzf_history
        history | fzf --height 40% --reverse | read -l cmd
        and commandline $cmd
    end

    bind \cr fzf_history

    zoxide init fish | source
    fzf --fish | source
    starship init fish | source

end
