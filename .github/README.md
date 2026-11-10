# dotfiles

Plain Arch + Hyprland on a ThinkPad. Catppuccin Mocha everywhere.

Stored as a **bare git repo** (`~/.cfg`) whose work tree is `$HOME`: the files in this repo are the real
config files in place (`.config/hypr/...`), no symlinks. Only files added on purpose are tracked.

```fish
alias dots 'git --git-dir=$HOME/.cfg --work-tree=$HOME'   # in .config/fish/config.fish
dots status          # changes to tracked files only
dots add .config/hypr/hyprland.lua
dots commit -m "..."
dots push
```

| Path | What |
|---|---|
| .config/hypr | Hyprland (Lua config), hyprlock, hypridle, helper scripts |
| .config/quickshell | Bar, Settings window (Super+I), volume/brightness/screenshot popups |
| .config/rofi | Launcher, clipboard, power and opacity menus |
| .config/kitty, fish, starship.toml | Terminal, shell, prompt |
| .config/nvim | Neovim config |
| .config/btop, yazi, fastfetch, gh, bat, tealdeer | CLI tools |
| .config/gtk-3.0, gtk-4.0, kdeglobals, fontconfig | Catppuccin GTK/Qt colors, subpixel font rendering |
| .config/spotify-launcher.conf, .local/bin, .local/share/applications | Spotify (native Wayland + SpotX re-patch), desktop entries |
| .local/share/sddm-theme/material-you-mocha | Sign-in theme (qylock Material-you-dark recolored); copy to `/usr/share/sddm/themes/` |

## New machine

```fish
git clone --bare https://github.com/Crophics/dotfiles.git ~/.cfg
alias dots 'git --git-dir=$HOME/.cfg --work-tree=$HOME'
dots checkout bare-home     # move any clashing stock files aside first
dots config status.showUntrackedFiles no
```

Older setups (illogical-impulse, noctalia, caelestia, 43pr, symlink layout `arch-transition`) are other branches.
