#!/bin/sh
# Build the bar (Rust) and install it to ~/.local/bin/bar.
# Crates are downloaded into a temporary folder that is deleted when the build ends (nothing stays in ~/.cargo).
# Needs: cargo, cairo, pango, libdbus (all installed).
set -e
cd "$(dirname "$0")"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
CARGO_HOME="$T/cargo" CARGO_TARGET_DIR="$T/target" cargo build --release --locked
mkdir -p "$HOME/.local/bin"
install -m755 "$T/target/release/bar" "$HOME/.local/bin/bar.new" && mv -f "$HOME/.local/bin/bar.new" "$HOME/.local/bin/bar"
echo "installed ~/.local/bin/bar"
