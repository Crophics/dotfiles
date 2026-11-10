# ~/.local/bin on PATH for every fish shell
fish_add_path -g ~/.local/bin

set -gx EDITOR nvim
set -gx VISUAL nvim

# Colored bold text in less/man pages
set -gx LESS_TERMCAP_md (tput bold 2>/dev/null; tput setaf 2 2>/dev/null)
set -gx LESS_TERMCAP_me (tput sgr0 2>/dev/null)

# pkgfile: suggest the package when a command isn't found
test -r /usr/share/doc/pkgfile/command-not-found.fish
and source /usr/share/doc/pkgfile/command-not-found.fish

if status is-interactive
    # Catppuccin Mocha colors for commands, errors, suggestions (fish built-in theme)
    fish_config theme choose catppuccin-mocha
    set fish_greeting

    # Prompt, smarter cd (z), fuzzy finder (Ctrl+R history, Ctrl+T files)
    if test "$TERM" != linux; and type -q starship
        starship init fish | source
    end
    type -q zoxide; and zoxide init fish --cmd cd | source   # cd = zoxide: `cd dots` jumps to ~/git/dotfiles
    type -q fzf; and fzf --fish | source

    # Ctrl+Backspace deletes a word, Ctrl+Z undoes
    bind \cH backward-kill-word
    bind \cZ undo

    # yazi: cd into the directory you were browsing when you quit
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # ssh: kitty's ssh kitten, except plain ssh for the Windows desktop
    # (the kitten's Unix bootstrap breaks on Windows OpenSSH)
    if test "$TERM" = xterm-kitty
        function ssh --description 'kitten ssh, plain ssh for the Windows desktop'
            if string match -qr -- '(^|@)(desktop|10\.106\.22\.85)$' $argv
                command ssh $argv
            else
                kitten ssh $argv
            end
        end
    end

    # Clear (kitty needs the scrollback escape too)
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias c clear

    # ls
    if test "$TERM" != linux; and type -q eza
        alias ls 'eza --icons=auto'
        alias ll 'eza -la --icons=auto --group-directories-first'
        alias la 'eza -a --icons=auto'
    end

    alias .. 'cd ..'

    # pacman
    alias rmpkg 'sudo pacman -Rsn'
    alias fixpacman 'sudo rm /var/lib/pacman/db.lck'

    # cleancache: old package versions (keeps the newest of each for rollback), orphan packages (asks first),
    # and yay's AUR build files
    function cleancache
        sudo paccache -rk1; and sudo paccache -ruk0
        set -l orphans (pacman -Qdtq)
        if test (count $orphans) -gt 0
            sudo pacman -Rns $orphans
        else
            echo "No orphan packages."
        end
        rm -rf ~/.cache/yay
        echo "Done."
    end

    # modern replacements (only when typed; scripts still get the originals, e.g. `command grep`)
    type -q rg;    and alias grep rg
    type -q fd;    and alias find fd
    type -q bat;   and alias cat 'bat --paging=never'
    type -q dust;  and alias du dust
    type -q duf;   and alias df duf
    type -q btop;  and alias top btop

    # misc
    alias make 'make -j(nproc)'
    alias ninja 'ninja -j(nproc)'
    alias n ninja
    alias jctl 'journalctl -p 3 -xb'
    alias tb 'nc termbin.com 9999'
end
