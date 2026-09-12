#!/usr/bin/env bash
# Bootstrap this dotfiles repo on a fresh CachyOS/Arch install.
# Safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=$(find "$REPO_DIR" -maxdepth 1 -mindepth 1 -type d -not -name packages -not -name '.git' -printf '%f\n')

echo "==> Installing base tooling (stow, git)"
sudo pacman -S --needed --noconfirm stow git base-devel

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay (AUR helper)"
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

echo "==> Installing pacman packages from packages/pacman.txt"
sudo pacman -S --needed - < "$REPO_DIR/packages/pacman.txt"

if [ -s "$REPO_DIR/packages/aur.txt" ]; then
  echo "==> Installing AUR packages from packages/aur.txt"
  yay -S --needed - < "$REPO_DIR/packages/aur.txt"
fi

if [ -s "$REPO_DIR/packages/flatpak.txt" ]; then
  echo "==> Installing flatpak apps from packages/flatpak.txt"
  sudo pacman -S --needed --noconfirm flatpak
  xargs -r -a "$REPO_DIR/packages/flatpak.txt" -I{} flatpak install -y flathub {}
fi

echo "==> Stowing dotfile packages into \$HOME"
for pkg in $STOW_PACKAGES; do
  stow -d "$REPO_DIR" -t "$HOME" -R "$pkg"
done

echo "==> Done. Log out/in (or restart Hyprland) for session-level changes to take effect."
echo "Note: qylock (lockscreen) is not vendored here — see README for how to fetch/build it."
