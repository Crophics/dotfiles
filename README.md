# dotfiles

Personal CachyOS laptop running [Ryoku](https://ryoku.dev) (a Hyprland + Quickshell
desktop layered on Arch/CachyOS). Ryoku owns the desktop's base configs; this repo
holds the personal layer on top, as [GNU Stow](https://www.gnu.org/software/stow/)
packages symlinked into `$HOME`, plus everything Ryoku doesn't manage.

Branches: `ryoku` (this), `noctalia` (Luke Elrod-based Hyprland + Noctalia),
`ii` (end-4 illogical-impulse, the original setup).

## Fresh machine

1. Base CachyOS install, then Ryoku's in-place converter — **turn the NVIDIA toggle
   off** (see below):
   `curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/ryoku-shell-installer/install.sh | bash`
2. `git clone` this repo to `~/git/dotfiles`, `git checkout ryoku`, `./install.sh`.

## How the personal layer sits on Ryoku

Ryoku's `ryoku materialize` (run by `ryoku update`) re-lays every config it ships, so
personal changes live only in the override files it never touches:

- `hypr/.config/hypr/user.lua` — the old illogical-impulse keybind layout ported to
  Ryoku (unbinds a Ryoku default first where keys collide). Loaded last by Hyprland.
- `fish/.config/fish/user.fish` — aliases, `y`, `nvidia-on`, pyenv; sourced last by
  Ryoku's `config.fish`.
- `kitty/.config/kitty/user.conf` — font and margin; colors stay Ryoku's.
- `zsh/.config/starship.toml` — the pill prompt (ANSI colors, follows the palette).
  Ryoku ships its own `starship.toml`, so this is also linked from
  `~/.config/ryoku/user_edits/starship.toml`, Ryoku's whole-file override
  folder, which wins on every update.
- `local-bin/` — `fuzzel-emoji` (Super+Period) and `scratchpad-focus`.
- `nvim` — Luke Elrod's config. Ryoku seeds missing files into `~/.config/nvim` on
  update, so its LazyVim plugin files are kept but neutralized (`return {}`) in
  `lua/plugins/ryoku*.lua` rather than deleted.
- Not tracked here because Ryoku generates them from the wallpaper: GTK `gtk.css`,
  yazi `theme.toml`, kitty `current-theme.conf`, qt6ct.

**NVIDIA:** the T550 dGPU must not load at boot (it freezes suspend/resume); load it
for games with `nvidia-on`. Ryoku's NVIDIA step / `ryoku doctor` add
`/etc/mkinitcpio.conf.d/nvidia.conf` and enable `nvidia-{suspend,hibernate,resume}`
whenever they see the module loaded — reboot before `ryoku update` after gaming.

## Layout

Each top-level directory is a stow package mirroring its path under `$HOME`.
Besides the personal layer above: `fastfetch`, `cava`, `lazygit`, `micro`, `gh`,
`qalculate`, `satty`, `tmux`, `shell` (bash fallback), `gtk`/`qt`/`kde-misc`/
`fontconfig`/`local-share-theming` (KDE app settings, cursor), `session`
(environment.d, mimeapps.list), `desktop-apps`, `wallpapers`, `nvim-lazyvim`
(`NVIM_APPNAME=nvim-lazyvim nvim`), `nvidia`, `cachyos`, `xdg-user-dirs`.

`archive/` (never stowed): `noctalia-era/` (that branch's Hyprland/Noctalia configs
and the files Ryoku took over), plus the illogical-impulse setup.

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

After Ryoku is installed (see "Fresh machine" above):

```sh
git clone <this-repo-url> ~/git/dotfiles
cd ~/git/dotfiles && git checkout ryoku
./install.sh
```

This installs `stow`/`yay` if missing, installs everything in `packages/`, then
stows every package into `$HOME` (backing up any file already in the way, e.g.
Ryoku's seeded `hypr/user.lua`), and links the starship prompt into Ryoku's
`user_edits` override folder. Re-run any time — it's idempotent. Then
`ryoku reload` (or log out/in).

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

Ryoku's: matugen derives the palette from the wallpaper (Super+W / Ctrl+Super+T)
and recolors the shell, Hyprland, kitty, GTK, Qt and yazi. The starship prompt uses
the 16 ANSI colors, so it follows along. Neovim stays Gruvbox.

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
