# dotfiles

Plain Arch + Hyprland on a ThinkPad. Catppuccin Mocha everywhere.

This repo is a **bare git repo** stored in `~/.dotfiles`, and its work tree is the whole home folder.
The files here are the real config files in their real places (`~/.config/hypr/...`). There are no
symlinks, and only files that were added on purpose are tracked.

## What's in here

| Path | What |
|---|---|
| `.config/hypr` | Hyprland (Lua config), hyprlock, hypridle, helper scripts |
| `.config/quickshell` | Bar, Settings window (Super+I), volume/brightness/screenshot popups |
| `.config/rofi` | Launcher, clipboard, power and opacity menus |
| `.config/kitty`, `.config/fish`, `.config/starship.toml` | Terminal, shell (aliases, `dots`, `cleancache`), prompt |
| `.config/nvim` | Neovim config |
| `.config/btop`, `yazi`, `fastfetch`, `gh`, `bat`, `tealdeer` | CLI tools |
| `.config/gtk-3.0`, `gtk-4.0`, `kdeglobals`, `fontconfig` | Catppuccin GTK/Qt colors, subpixel font rendering |
| `.config/spotify-launcher.conf`, `.local/bin`, `.local/share/applications` | Spotify (native Wayland + SpotX re-patch), desktop entries |
| `.local/share/sddm-theme/material-you-mocha` | Sign-in theme (qylock Material-you-dark recolored to Catppuccin) |
| `.gitignore` | Safety net: keys, tokens, shell history, etc. can never be added |
| `.github/README.md` | This file |

## The `dots` command

`dots` is plain `git` pointed at this repo. It's defined in `.config/fish/config.fish`:

```fish
alias dots 'git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

It works from any folder, and every normal git command works with `dots` in place of `git`.

## Everyday use

```fish
dots status                      # what changed in tracked files (untracked files are hidden on purpose)
dots diff                        # the changes themselves
dots add -u                      # stage every change to tracked files
dots commit -m "what changed"    # commit
dots push                        # send to GitHub
dots pull                        # get changes made on another machine
```

## Tracking files

```fish
dots add .config/foo/foo.conf    # start tracking a new file (or a whole folder: dots add .config/foo)
dots ls-files                    # list everything that is tracked
dots ls-files .config/hypr       # ...in one folder
dots rm --cached path/to/file    # stop tracking a file (keeps it on disk)
dots rm --cached -r path/folder  # stop tracking a folder (keeps it on disk)
```

Before adding a folder, check it for private files (logins, tokens, keys). `dots status` after
`dots add` shows exactly what got staged; `dots restore --staged <path>` unstages something.

## History and undo

```fish
dots log --oneline               # all commits
dots log --oneline -- .config/hypr/hyprland.lua   # commits that touched one file
dots show <commit>               # what one commit changed
dots restore path/to/file        # throw away uncommitted changes to a file
dots restore --source <commit> path/to/file       # bring back an old version of a file
dots revert <commit>             # undo a whole commit (as a new commit)
```

## Branches

```fish
dots branch -a                   # list branches (bare-home = this setup)
dots switch <branch>             # switch setups (replaces the tracked files in ~ - commit first!)
```

Older setups (illogical-impulse, noctalia, caelestia, 43pr, and `arch-transition` = the old symlink
layout of this setup) are kept as branches.

## Setting up a new machine

1. Install git and fish, then clone the repo as a bare repo:

   ```fish
   git clone --bare https://github.com/Crophics/dotfiles.git ~/.dotfiles
   function dots; git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv; end
   dots config status.showUntrackedFiles no
   dots config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
   dots fetch
   ```

2. Put the files in place:

   ```fish
   dots checkout bare-home
   ```

3. If step 2 fails with "untracked working tree files would be overwritten", the new machine already
   has default versions of some files. Move them to `~/.dotfiles-backup` and try again:

   ```fish
   for f in (dots checkout bare-home 2>&1 | string match -r '^\s+\S.*' | string trim)
       mkdir -p (dirname ~/.dotfiles-backup/$f); mv ~/$f ~/.dotfiles-backup/$f
   end
   dots checkout bare-home
   ```

4. Open a new terminal (fish now has the `dots` alias from the repo) and check:

   ```fish
   dots status
   ```

5. Install the sign-in theme (system folder, needs sudo):

   ```fish
   sudo cp -r ~/.local/share/sddm-theme/material-you-mocha /usr/share/sddm/themes/
   ```

   The theme's `bg.png` (wallpaper copy) and `font/` folder aren't in git. See that folder's README.

From bash (before fish is set up) the alias is:

```bash
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```
