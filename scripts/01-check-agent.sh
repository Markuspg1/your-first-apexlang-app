#!/usr/bin/env bash
# Detect a coding agent (CLI on PATH or installed .app bundle).
# If none is found, install Antigravity via Homebrew cask.
set -u
. "$(dirname "$0")/_lib.sh"

# 1. CLIs on PATH
for cli in antigravity claude cursor-agent aider gemini codex opencode; do
  if have "$cli"; then
    ok "agent CLI found: $cli  ($(command -v "$cli"))"
    exit 0
  fi
done

# 2. Installed macOS .app bundles (IDE-embedded agents still count)
for entry in \
  "/Applications/Antigravity.app|Antigravity" \
  "/Applications/Cursor.app|Cursor" \
  "/Applications/Windsurf.app|Windsurf"
do
  path="${entry%|*}"
  name="${entry#*|}"
  if [ -d "$path" ]; then
    ok "$name is installed at $path"
    exit 0
  fi
done

# 3. Nothing found — install Antigravity
warn "no coding-agent CLI or app detected."

if ! have brew; then
  err "Homebrew is required to auto-install."
  echo "  Install Homebrew first:  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo
  echo "  Or install an agent manually:"
  echo "    Antigravity  →  https://antigravity.google/download"
  echo "    Claude Code  →  npm install -g @anthropic-ai/claude-code"
  echo "    Cursor       →  brew install --cask cursor"
  echo "    Aider        →  pip install aider-chat"
  exit 1
fi

info "installing Antigravity via Homebrew cask..."
brew install --cask antigravity

if [ -d /Applications/Antigravity.app ]; then
  ok "Antigravity installed at /Applications/Antigravity.app"
  echo
  info "Launch it to sign in:"
  echo "    open -a Antigravity"
else
  err "install command completed but /Applications/Antigravity.app is missing"
  err "check the brew output above for errors"
  exit 1
fi
