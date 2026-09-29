#!/usr/bin/env bash
# Install (or verify) Oracle SQLcl via Homebrew cask.
# SQLcl 26.1+ ships the APEXlang toolchain (apex generate / validate / import).
set -u
. "$(dirname "$0")/_lib.sh"

if have sql; then
  ok "sqlcl already installed: $(sql -V 2>&1 | head -1)"
  exit 0
fi

if ! have brew; then
  err "Homebrew is required. Install it first from https://brew.sh"
  exit 1
fi

info "installing sqlcl via Homebrew cask..."
brew install --cask sqlcl

# Homebrew cask sometimes doesn't put `sql` on PATH; find and symlink if needed.
if ! have sql; then
  bin=$(find /opt/homebrew/Caskroom/sqlcl -maxdepth 4 -name 'sql' -type f 2>/dev/null | head -1)
  if [ -n "$bin" ]; then
    info "creating /opt/homebrew/bin/sql symlink → $bin"
    ln -sf "$bin" /opt/homebrew/bin/sql
  fi
fi

if have sql; then
  ok "sqlcl installed: $(sql -V 2>&1 | head -1)"
else
  err "installation reported success but 'sql' is not on PATH"
  exit 1
fi
