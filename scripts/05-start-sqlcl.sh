#!/usr/bin/env bash
# Drop into SQLcl in the presentation directory.
# APEXlang commands (apex generate, validate, import, export) are built in.
set -u
. "$(dirname "$0")/_lib.sh"

if ! have sql; then
  err "sqlcl not installed — run scripts/03-install-sqlcl.sh first"
  exit 1
fi

HERE=$(cd "$(dirname "$0")/.." && pwd)
info "starting SQLcl in $HERE"
echo "  Try:   apex generate -name \"Hello Webinar\" -dir ./projects"
echo "         apex validate -input ./projects/starter-app"
echo
cd "$HERE" && exec sql -nolog
