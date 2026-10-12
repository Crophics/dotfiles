# Personal fish setup, layered on Ryoku's config.fish (which sources this last).
# Ryoku already handles: ~/.local/bin on PATH, EDITOR/VISUAL=nvim, no greeting,
# starship, fzf, fastfetch on open (ryoku-fastfetch, uses ~/.config/fastfetch),
# and zoxide hooked into `cd` (`cdi` for the interactive pick).

# Custom `less`/`man` page colors (ported from cachyos-config.zsh)
set -gx LESS_TERMCAP_md (tput bold 2>/dev/null; tput setaf 2 2>/dev/null)
set -gx LESS_TERMCAP_me (tput sgr0 2>/dev/null)

# pkgfile "command not found" handler (fish-native version)
test -f /usr/share/doc/pkgfile/command-not-found.fish
and source /usr/share/doc/pkgfile/command-not-found.fish

pyenv init - | source

if status is-interactive
    # Auto-start Hyprland on a bare tty1 login (SDDM handles the normal
    # graphical path; this is just the fallback if you ever land on a raw console).
    if test -z "$DISPLAY"; and test "$XDG_VTNR" = 1
        mkdir -p ~/.cache
        exec start-hyprland >~/.cache/hyprland.log 2>&1
    end

    # Readline-ish keybindings (ported from zshrc.d/shortcuts.zsh)
    bind \cH backward-kill-word
    bind \cZ undo

    # yazi wrapper: cd to the directory you were browsing on exit
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias cl "printf '\033[2J\033[3J\033[1;1H'"
    alias c clear
    alias z cd # Ryoku hooks zoxide into cd
    alias pamcan pacman
    alias g git
    alias gs 'git status'
    alias gp 'git pull'
    alias .. 'cd ..'
    alias code codium
    if test "$TERM" != linux
        # short listings, like before (Ryoku's `ls` is a long listing)
        alias ls 'eza --icons=auto'
        alias ll 'eza -la --icons=auto --group-directories-first'
        alias la 'eza -a --icons=auto'
    end
    if test "$TERM" = xterm-kitty
        alias ssh 'kitten ssh'
    end

    # NVIDIA is kept from auto-loading at boot (only needed for games; loaded
    # unused it caused suspend/resume freezes). Load it before a game, and
    # reboot before `ryoku update`/`ryoku doctor`, which re-add boot-time
    # loading when they see the module loaded.
    alias nvidia-on 'sudo modprobe nvidia_drm modeset=1 nvidia_modeset nvidia_uvm nvidia'

    # Ported from cachyos-config.zsh
    alias make 'make -j(nproc)'
    alias ninja 'ninja -j(nproc)'
    alias n ninja
    alias rmpkg 'sudo pacman -Rsn'
    alias cleanch 'sudo pacman -Scc'
    alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
    alias update 'ryoku update'
    alias apt 'man pacman'
    alias apt-get 'man pacman'
    alias please sudo
    alias tb 'nc termbin.com 9999'
    alias jctl 'journalctl -p 3 -xb'
    alias rip "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
end
