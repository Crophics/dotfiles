# dotfiles

Personal CachyOS + Hyprland rice, based on
[Luke Elrod's dotfiles](https://github.com/LukeElrod/dotfiles) and
[nvim config](https://github.com/LukeElrod/nvim): Hyprland's Lua config with the
scrolling layout and the [Noctalia](https://docs.noctalia.dev/) shell, with colors
generated from the wallpaper. Managed as a set of
[GNU Stow](https://www.gnu.org/software/stow/) packages so each app's config lives
in its own directory and gets symlinked into `$HOME` on install.

**Goal: full-system recovery.** If this machine died today, `git clone` this repo
onto a base CachyOS-Hyprland install and running `./install.sh` should get you
back to (functionally) where you are now — packages, configs, wallpapers, and
the services that make the rice actually run.

## Layout

Each top-level directory is a stow package mirroring its path under `$HOME`, e.g.
`hypr/.config/hypr/...` symlinks to `~/.config/hypr/...`.

- **Desktop**: `hypr` — upstream's modules (`monitors`, `env`, `look`, `input`,
  `keybinds`, `rules`, `autostart`) adapted for this laptop (single `eDP-1` at 1.2
  scale, no NVIDIA env vars since the iGPU drives the display, touchpad settings,
  qylock via hypridle), `system.lua` (behaviour carried over from the old config,
  incl. XWayland zero-scaling). `keybinds.lua` keeps the old illogical-impulse key layout
  (shell keys now call `noctalia msg`) plus upstream's double-tap-Super column
  toggle. Noctalia is the bar/launcher/notifications/clipboard/wallpaper
  (picker on Ctrl+Super+T, browsing `~/Pictures/Wallpapers`); its settings live in
  `~/.local/state/noctalia/settings.toml` (color scheme: builtin Gruvbox).
- **Session/login wiring**: `session` (environment.d, xdg-desktop-portal,
  mimeapps.list — Zen, Nautilus) — SDDM launches Hyprland directly via
  `start-hyprland`, no UWSM involved
- **UI toolkit theming**: `gtk`, `qt`, `kde-misc`, `fontconfig` — colors come from
  Noctalia's theme templates; cursor is Bibata-Modern-Ice
- **Terminal/CLI**: `kitty`, `fish` (the actual default shell —
  `chsh -s /usr/bin/fish`), `zsh` (just `starship.toml` — fish reads the same
  file), `shell` (bash, fallback only), `tmux`, `lazygit`, `btop`,
  `cava`, `fastfetch`, `yazi`, `micro`, `qalculate`, `gh`, `yay`
- **Editors**: `nvim` (Luke's config; agent terminal runs Claude Code, see
  `lua/user_settings.lua`), `nvim-lazyvim` (the previous LazyVim setup —
  `NVIM_APPNAME=nvim-lazyvim nvim`), `vscodium`
- **Wallpapers**: `wallpapers` (`~/Pictures/Wallpapers`)
- **Theming state**: `local-share-theming` (KDE color schemes, active cursor theme selector)
- **Misc**: `nvidia`, `cachyos`, `desktop-apps`, `xdg-user-dirs`
- **`archive/`** (never stowed by `install.sh`): the previous illogical-impulse /
  end-4 quickshell setup — `hypr-ii`, `quickshell`, `illogical-impulse`,
  `matugen`, `kde-material-you-colors`, `skwd-wall`, `fuzzel`, `wlogout`. To go
  back: unstow `hypr`, `stow -d archive -t ~ hypr-ii quickshell ...`.

Note: no `git` package here on purpose — `.gitconfig` isn't tracked (it carried
personal identity). Set your own `git config --global user.name/user.email`
after installing.

`packages/` holds manifests, not stow packages:
- `pacman.txt` — explicitly installed native packages (`pacman -Qqe`)
- `aur.txt` — foreign/AUR packages (`pacman -Qqem`)
- `flatpak.txt` — installed flatpak app IDs
- `systemd-user-enabled.txt` / `systemd-system-enabled.txt` — reference snapshot
  of what's enabled on the source machine. `install.sh` explicitly re-enables the
  two that are actually rice-critical (`hyprpolkitagent`, `ydotool`); the rest are
  mostly CachyOS install defaults (NetworkManager, bluetooth, cups, timers, etc.)
  — cross-check the system-level file if something's missing after a fresh install.

## Install on a new machine

```sh
git clone <this-repo-url> ~/git/dotfiles
cd ~/git/dotfiles
./install.sh
```

This installs `stow`/`yay` if missing, installs everything in `packages/`, then
stows every package into `$HOME`. Re-run any time — it's idempotent
(`stow -R`), and safe even if a graphical session already ran once and
auto-generated its own default configs (Hyprland does this) — `install.sh`
backs those up automatically before linking the real ones in.

**Best order on a truly fresh install**: pick no desktop environment / a
minimal profile in the installer, boot to a plain TTY, and run `install.sh`
from there *before* ever starting Hyprland for the first time. That way
nothing auto-generates a conflicting config and Hyprland's normal
autostart (which launches Noctalia, see `hypr/.config/hypr/autostart.lua`)
just works on the very first login. If you do end up logging into a bare
graphical session first (e.g. to get a terminal), that's fine too — just
run `install.sh` and then fully restart Hyprland once (log out/in, or
`hyprctl dispatch exit`) so it picks up the real config and autostarts
Noctalia.

To only (re)link configs without touching packages, run stow directly:

```sh
stow -d ~/git/dotfiles -t ~ hypr nvim kitty   # etc.
```

## Not included, on purpose

- `archive/quickshell` (`~/.config/quickshell/end4-pC`) **is** included as plain files (it's a forked/
  patched copy of the shell engine itself, not upstream-tracked here).
- **qylock** (lockscreen) is *not* vendored — the working checkout is ~1.8GB
  (mostly theme assets) and it's a separate forked/patched project. Clone and
  build it separately:
  ```sh
  git clone https://github.com/Darkkal44/qylock.git ~/.config/qylock-src
  ```
  If you want your local qylock patches preserved on GitHub too, fork it under
  your own account and push a branch there — that's a separate step from this repo.
- Browser profiles, Discord/Vesktop, Spotify, LibreOffice, Bitwarden, and other
  app-data-heavy directories are excluded — they're state/cache, not config, and
  can contain sensitive data.
- Secrets (`.ssh`, `.gnupg`, `.pki`, shell history, cookies) are never tracked here.

## Theming pipeline

Noctalia generates a palette from the wallpaper (`m3-content`) → its theme templates
write `~/.config/gtk-{3,4}.0/noctalia.css` (imported from `gtk.css`),
`~/.config/qt6ct/colors/noctalia.conf`, btop and cava themes, plus two user templates
in `noctalia/.config/noctalia/templates/`: Hyprland border colors
(`~/.local/share/noctalia-templates/hypr-colors.lua`, read by `look.lua`, Gruvbox
fallback) and kitty colors (`~/.config/kitty/noctalia-colors.conf`, included after
`gruvbox-dark.conf`). Starship uses the 16 ANSI colors, so the prompt follows kitty.
Neovim stays Gruvbox (plugin). Fixed Gruvbox instead:
`noctalia msg color-scheme-set builtin Gruvbox`.

## Troubleshooting

- **No audio, `pactl` says "Connection refused"**: `pipewire.service` and
  `wireplumber.service` can be active while the `pipewire-pulse` package is
  missing, which silently breaks every app that talks to PulseAudio (Firefox/Zen
  included) even though native PipeWire clients (`wpctl`) work fine. Fix:
  ```sh
  sudo pacman -S --needed pipewire-pulse
  systemctl --user restart pipewire pipewire-pulse wireplumber
  ```
  `pipewire-pulse` is now in `packages/pacman.txt` so a fresh `install.sh` run
  won't hit this.
