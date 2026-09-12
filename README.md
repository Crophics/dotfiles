# dotfiles

Personal CachyOS + Hyprland rice, built on the illogical-impulse / end-4 quickshell
shell with matugen-driven Material You theming. Managed as a set of
[GNU Stow](https://www.gnu.org/software/stow/) packages so each app's config lives
in its own directory and gets symlinked into `$HOME` on install.

**Goal: full-system recovery.** If this machine died today, `git clone` this repo
onto a base CachyOS-Hyprland install and running `./install.sh` should get you
back to (functionally) where you are now — packages, configs, wallpapers, and
the services that make the rice actually run.

## Layout

Each top-level directory is a stow package mirroring its path under `$HOME`, e.g.
`hypr/.config/hypr/...` symlinks to `~/.config/hypr/...`.

- **Shell core**: `hypr`, `illogical-impulse`, `quickshell`, `dankmaterialshell`,
  `matugen`, `kde-material-you-colors`, `rice-cooker`, `skwd-wall`
- **Session/login wiring**: `session` (systemd user units, autostart, uwsm,
  xdg-desktop-portal, environment.d, mimeapps.list)
- **UI toolkit theming**: `gtk`, `qt`, `kde-misc`, `fontconfig`, `wal`, `nwg-look`
- **Launcher/lock**: `fuzzel`, `wlogout`, `swaylock`, `satty`
- **Terminal/CLI**: `zsh`, `shell` (bash), `kitty`, `ghostty`, `alacritty`, `fish`,
  `lazygit`, `btop`, `cava`, `fastfetch`, `yazi`, `micro`, `qalculate`, `gh`, `yay`
- **Editors**: `nvim` (LazyVim-based), `vscode`, `vscodium`
- **Misc**: `nvidia`, `spicetify`, `cachyos`, `desktop-apps`, `xdg-user-dirs`

Note: no `git` package here on purpose — `.gitconfig` isn't tracked (it carried
personal identity). Set your own `git config --global user.name/user.email`
after installing.
- **Wallpapers**: `wallpapers` (`~/Pictures/Wallpapers`, ~105MB — the pool `skwd-wall`
  rotates through and `illogical-impulse` themes off of)
- **Theming state**: `local-share-theming` (KDE Material You `.colors` schemes,
  active cursor theme selector)

`packages/` holds manifests, not stow packages:
- `pacman.txt` — explicitly installed native packages (`pacman -Qqe`)
- `aur.txt` — foreign/AUR packages (`pacman -Qqem`)
- `flatpak.txt` — installed flatpak app IDs
- `systemd-user-enabled.txt` / `systemd-system-enabled.txt` — reference snapshot
  of what's enabled on the source machine. `install.sh` explicitly re-enables the
  two that are actually rice-critical (`skwd-daemon`, `ydotool`); the rest are
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
autostart (which launches quickshell itself, see `hypr/.config/hypr/hyprland/execs.lua`)
just works on the very first login. If you do end up logging into a bare
graphical session first (e.g. to get a terminal), that's fine too — just
run `install.sh` and then fully restart Hyprland once (log out/in, or
`hyprctl dispatch exit`) so it picks up the real config and autostarts
quickshell.

To only (re)link configs without touching packages, run stow directly:

```sh
stow -d ~/git/dotfiles -t ~ hypr quickshell matugen   # etc.
```

## Not included, on purpose

- `~/.config/quickshell/end4-pC` **is** included as plain files (it's a forked/
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

Wallpaper → `matugen` extracts a Material You palette → colors are templated out
to `hypr`, `gtk`, `qt`, `kitty`/`ghostty`/etc., and `kde-material-you-colors`
syncs the palette into KDE/Qt apps. `wal` config is also tracked for tools that
still read pywal-style palettes.

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
