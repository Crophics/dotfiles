# kitty's own process environment doesn't include ~/.local/bin (nothing
# upstream of it - Hyprland/greetd - adds it either; see
# ~/.config/environment.d/local-bin.conf for the session-wide fix, which
# only takes effect on next login). This covers it immediately for any
# fish shell, interactive or not, without needing to log out.
fish_add_path -g ~/.local/bin

# $EDITOR was unset, so yazi's default text-file opener
# (${EDITOR:-vi} %s) fell back to the literal command "vi" - which isn't
# installed on this system (only vim/nvim are), so opening any text file
# in yazi just errored out with a "command not found" exit code instead
# of opening anything. See ~/.config/environment.d/editor.conf for the
# session-wide fix (next login); this covers it immediately.
set -gx EDITOR nvim
set -gx VISUAL nvim

# Custom `less`/`man` page colors (ported from cachyos-config.zsh)
set -gx LESS_TERMCAP_md (tput bold 2>/dev/null; tput setaf 2 2>/dev/null)
set -gx LESS_TERMCAP_me (tput sgr0 2>/dev/null)

# pkgfile "command not found" handler (fish-native version)
source /usr/share/doc/pkgfile/command-not-found.fish

# Commands to run in interactive sessions can go here
if status is-interactive
    # Auto-start Hyprland on a bare tty1 login (SDDM handles the normal
    # graphical path; this is just the fallback if you ever land on a
    # raw console). Ported from the old, never-actually-sourced
    # zshrc.d/auto-Hypr.sh.
    if test -z "$DISPLAY"; and test "$XDG_VTNR" = 1
        mkdir -p ~/.cache
        exec start-hyprland >~/.cache/hyprland.log 2>&1
    end

    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != linux
        starship init fish | source
        # enable_transience
    end

    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # System info on startup (kitty only)
    # Deferred to the first prompt (like kitty's own shell-integration setup)
    # so it isn't wiped by a startup window-resize clearing the screen before
    # the first real prompt is marked.
    if test "$TERM" = xterm-kitty
        function __show_fastfetch_once --on-event fish_prompt
            functions --erase __show_fastfetch_once
            fastfetch
        end
    end

    zoxide init fish | source
    fzf --fish | source

    # Readline-ish keybindings (ported from zshrc.d/shortcuts.zsh)
    bind \cH backward-kill-word
    bind \cZ undo

    # yazi wrapper: cd to the directory you were browsing on exit
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
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
    alias pamcan pacman
    alias q 'qs -c end4-pC'
    alias g git
    alias gs 'git status'
    alias gp 'git pull'
    alias .. 'cd ..'
    alias code codium
    if test "$TERM" != linux
        alias ls 'eza --icons=auto'
        alias ll 'eza -la --icons=auto --group-directories-first'
        alias la 'eza -a --icons=auto'
    end
    if test "$TERM" = xterm-kitty
        alias ssh 'kitten ssh'
    end

    # NVIDIA is blacklisted from auto-loading at boot (only needed for games,
    # and being loaded unused was causing suspend/resume freezes - see
    # ~/.config/CLAUDE.md). Load it manually before launching a game.
    alias nvidia-on 'sudo modprobe nvidia_drm modeset=1 nvidia_modeset nvidia_uvm nvidia'

    # Ported from cachyos-config.zsh
    alias make 'make -j(nproc)'
    alias ninja 'ninja -j(nproc)'
    alias n ninja
    alias c clear
    alias rmpkg 'sudo pacman -Rsn'
    alias cleanch 'sudo pacman -Scc'
    alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
    alias update 'sudo pacman -Syu'
    alias apt 'man pacman'
    alias apt-get 'man pacman'
    alias please sudo
    alias tb 'nc termbin.com 9999'
    alias jctl 'journalctl -p 3 -xb'
    alias rip "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
end