#!/usr/bin/env bash
#
# Install with-secrets to ~/.local/bin (or $PREFIX/bin if $PREFIX is set).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/dokioco/with-secrets/main/install.sh | bash
#   ./install.sh                # from a checkout
#   PREFIX=/usr/local sudo ./install.sh
#
# Env vars:
#   PREFIX          install prefix (default: $HOME/.local)
#   WITH_SECRETS_REF git ref to install from (default: main) - only used when fetching over HTTPS
#   INSTALL_CHAMBER if "1", also install chamber if missing

set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
REF="${WITH_SECRETS_REF:-main}"
RAW_URL="https://raw.githubusercontent.com/dokioco/with-secrets/${REF}/with-secrets"

say() { echo "==> $*"; }
warn() { echo "==> $*" >&2; }

mkdir -p "$BIN_DIR"

if [ -f "$(dirname "$0")/with-secrets" ]; then
  say "Installing with-secrets from local checkout to $BIN_DIR/with-secrets"
  install -m 0755 "$(dirname "$0")/with-secrets" "$BIN_DIR/with-secrets"
else
  say "Downloading with-secrets from $RAW_URL"
  curl -fsSL "$RAW_URL" -o "$BIN_DIR/with-secrets"
  chmod 0755 "$BIN_DIR/with-secrets"
fi

# --- check chamber -----------------------------------------------------------

if ! command -v chamber >/dev/null 2>&1; then
  warn "chamber is not installed."
  if [ "${INSTALL_CHAMBER:-0}" = "1" ]; then
    say "Installing chamber..."
    case "$(uname -s)" in
      Darwin)
        if command -v brew >/dev/null 2>&1; then
          brew install chamber
        else
          warn "Homebrew not found. Install chamber manually: https://github.com/segmentio/chamber"
        fi
        ;;
      Linux)
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        DEST="${BIN_DIR}/chamber"
        curl -fsSL "https://github.com/segmentio/chamber/releases/latest/download/chamber-v3.1.5-linux-${ARCH}" -o "$DEST"
        chmod 0755 "$DEST"
        say "Installed chamber to $DEST"
        ;;
      *)
        warn "Unknown OS $(uname -s). Install chamber manually: https://github.com/segmentio/chamber"
        ;;
    esac
  else
    warn "To install chamber automatically, re-run with INSTALL_CHAMBER=1"
    warn "Or see: https://github.com/segmentio/chamber"
  fi
fi

# --- check awscli ------------------------------------------------------------

if ! command -v aws >/dev/null 2>&1; then
  warn "AWS CLI is not installed. Install from https://aws.amazon.com/cli/"
fi

# --- PATH check --------------------------------------------------------------

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    warn ""
    warn "$BIN_DIR is not on your PATH."
    warn "Add this to your shell rc file (~/.zshrc, ~/.bashrc, etc):"
    warn ""
    warn "  export PATH=\"$BIN_DIR:\$PATH\""
    warn ""
    ;;
esac

say "Done. Run: with-secrets --help"
