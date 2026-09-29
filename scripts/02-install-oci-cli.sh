#!/usr/bin/env bash
# Install (or verify) Oracle Cloud Infrastructure CLI via Homebrew.
set -u
. "$(dirname "$0")/_lib.sh"

if have oci; then
  ok "oci already installed: $(oci --version 2>&1 | head -1)"
  exit 0
fi

if ! have brew; then
  err "Homebrew is required. Install it first from https://brew.sh"
  exit 1
fi

info "installing oci-cli via Homebrew..."
brew install oci-cli

if have oci; then
  ok "oci installed: $(oci --version 2>&1 | head -1)"
else
  err "installation reported success but 'oci' is not on PATH"
  exit 1
fi
