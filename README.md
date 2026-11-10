# dotfiles

Plain Arch + Hyprland on a ThinkPad (apollo). Catppuccin Mocha everywhere.
Each folder mirrors `$HOME` and is symlinked into place (e.g. `hypr/.config/hypr` -> `~/.config/hypr`).

| Folder | What |
|---|---|
| hypr | Hyprland (Lua config), hyprlock, hypridle, helper scripts |
| quickshell-43pr | Bar, Settings window (Super+I), volume/brightness/screenshot popups |
| rofi | Launcher, clipboard, power and opacity menus |
| kitty, fish, zsh | Terminal, shell (fish), starship prompt (`zsh/.config/starship.toml`) |
| nvim | Neovim config |
| btop, yazi, fastfetch, gh | CLI tools |
| gtk, kde-colors, fontconfig | Catppuccin GTK/Qt colors, subpixel font rendering |
| desktop-apps, local-bin | Spotify (native Wayland + SpotX re-patch), desktop entries |
| sddm | Sign-in theme `material-you-mocha` (qylock Material-you-dark recolored); copy to `/usr/share/sddm/themes/` |

Older setups (illogical-impulse, noctalia, caelestia, 43pr, ...) live on their own branches on GitHub.
