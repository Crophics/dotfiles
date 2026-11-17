#!/bin/sh
# Build the osd popup (Rust) and install it to ~/.local/bin/osd.
# The crates it needs are downloaded into a temporary folder that is deleted when the build ends,
# so nothing is left behind in ~/.cargo. Needs: cargo, plus cairo and pango (already installed).
set -e
cd "$(dirname "$0")"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
CARGO_HOME="$T/cargo" CARGO_TARGET_DIR="$T/target" cargo build --release --locked
mkdir -p "$HOME/.local/bin"
install -m755 "$T/target/release/osd" "$HOME/.local/bin/osd"
echo "installed ~/.local/bin/osd"
