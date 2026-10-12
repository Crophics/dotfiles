# dotfiles

Personal CachyOS laptop running Hyprland with the **Caelestia** shell: the
[midnight-shell](https://github.com/dim-ghub/midnight-shell) fork of
[caelestia-dots/shell](https://github.com/caelestia-dots/shell) and its
[midnight-cli](https://github.com/dim-ghub/midnight-cli). Everything is managed as
[GNU Stow](https://www.gnu.org/software/stow/) packages symlinked into `$HOME`.

Branches: `caelestia` (this), `ryoku` ([Ryoku](https://ryoku.dev) desktop),
`noctalia` (Luke Elrod-based Hyprland + Noctalia), `ii` (end-4 illogical-impulse).

> The fork's author says midnight-shell/-cli are no longer maintained (they track
> upstream for now). If they break, the upstream `caelestia-shell-git` +
> `caelestia-cli` packages drop in (same config files).

## Fresh machine

1. Base CachyOS install (SDDM). `git clone` this repo to `~/git/dotfiles`,
   `git checkout caelestia`, run `./install.sh`.
2. Prompts to expect from the AUR installs:
   - `midnight-cli-git` asks "Are you currently using CachyOS?" and a support-waiver
     agreement: answer `y` to both (it only asks).
   - the fork replaces the repo `quickshell` with AUR `quickshell-git` and removes
     `polkit-gnome` (it ships its own polkit agent): answer `y`.
   - `install.sh` installs `quickshell-git` first, by explicit AUR name. Otherwise yay
     resolves midnight-shell-git's `quickshell-git` dependency to CachyOS's
     `noctalia-qs`, which it conflicts with.
3. Reboot; pick Hyprland at the SDDM login. Hyprland's autostart runs `caelestia shell -d`.

## How it is put together

- **Hyprland config** = the official [caelestia-dots](https://github.com/caelestia-dots/caelestia)
  `hypr/` tree, deployed by `local-bin/.local/bin/caelestia-dots-sync` into the real
  folder `~/.config/hypr` (not tracked here; rerun the script to update). `caelestia
  install` is deliberately not used: it would overwrite fish/starship/fastfetch/btop,
  install `polkit-gnome` (conflicts with the fork), and run a Firefox profile script.
- **Personal overrides** (stowed from `caelestia/.config/caelestia/`, read by the dots'
  `hyprland.lua` and untouched by updates): `hypr-vars.lua` (apps = kitty/Zen/Nautilus/
  VSCodium, cursor, Super+Return/Space aliases) and `hypr-user.lua` (the fork's
  clipboard/emoji pickers, workspace overview, window switcher, keybind sheet, OCR,
  Bitwarden).
- The shell itself is installed system-wide under `/etc/xdg/quickshell/caelestia`;
  its settings go in `~/.config/caelestia/shell.json` (not created by default).
- Everything else is an ordinary stow package: fish (`config.fish`), kitty
  (Gruvbox), starship (ANSI colors), fastfetch, nvim (Luke Elrod's config), tmux, ...
- **NVIDIA:** the T550 dGPU must not load (it freezes suspend/resume); load it for
  games with `nvidia-on`. Quickshell shells load libcuda at login, which makes
  `nvidia-modprobe` load the module by name past the blacklist, so
  `/etc/modprobe.d/nvidia-lockout.conf` (`install nvidia /usr/bin/false`) blocks
  that and `nvidia-on` moves it aside just long enough to load the module.

## Layout

Each top-level directory is a stow package mirroring its path under `$HOME`.
Besides the Caelestia layer above: `fastfetch`, `cava`, `lazygit`, `micro`, `gh`,
`qalculate`, `satty`, `tmux`, `shell` (bash fallback), `gtk`/`qt`/`kde-misc`/
`fontconfig`/`local-share-theming` (KDE app settings, cursor), `session`
(environment.d, mimeapps.list), `desktop-apps`, `wallpapers`, `nvim-lazyvim`
(`NVIM_APPNAME=nvim-lazyvim nvim`), `nvidia`, `cachyos`, `xdg-user-dirs`.

`archive/` (never stowed): `ryoku-era/` and `noctalia-era/` (those branches' Hyprland
configs and the files Ryoku took over), plus the illogical-impulse setup.

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

See "Fresh machine" above. `./install.sh` installs `stow`/`yay` if missing, installs
everything in `packages/`, stows every package into `$HOME` (backing up any real file
already in the way), then deploys the Caelestia Hyprland config. Re-run any time; it
is idempotent.

To only (re)link configs without touching packages, run stow directly:

```sh
stow -d ~/git/dotfiles -t ~ caelestia nvim kitty   # etc.
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

## Theming

Caelestia's scheme (`caelestia scheme set -n caelestia|dynamic`; `dynamic` follows the
wallpaper) colors the shell and Hyprland borders (`~/.config/hypr/scheme/current.lua`,
generated, not tracked). kitty keeps its own Gruvbox theme and Neovim is Gruvbox. The
starship prompt uses the 16 ANSI colors, so it follows the terminal.

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
