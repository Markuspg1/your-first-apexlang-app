#!/usr/bin/env bash
# Install Oracle's official agent skills (github.com/oracle/skills) for the
# coding agent: APEXlang grammar + canonical templates + compiler-backed
# property queries, plus the Database (SQLcl/ORDS) and OCI domains.
#
# Idempotent: skips domains already present. Installs for Claude Code by
# copying into ~/.claude/skills (override with SKILLS_DIR). Other agents:
# see the printed `npx skills add` alternative.
set -u
. "$(dirname "$0")/_lib.sh"

SKILLS_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"
REPO="https://github.com/oracle/skills.git"
# repo path -> local skill dir name
DOMAINS="apex/apexlang:apexlang db:oracle-db oci:oracle-oci"

have git || { err "git is required"; exit 1; }
mkdir -p "$SKILLS_DIR"

missing=""
for pair in $DOMAINS; do
  dst="${pair##*:}"
  if [ -f "$SKILLS_DIR/$dst/SKILL.md" ]; then
    ok "$dst already installed ($SKILLS_DIR/$dst)"
  else
    missing="$missing $pair"
  fi
done

if [ -n "$missing" ]; then
  tmp=$(mktemp -d -t oracle-skills.XXXXXX)
  trap 'rm -rf "$tmp"' EXIT
  info "cloning oracle/skills (shallow)…"
  git clone --quiet --depth 1 "$REPO" "$tmp/skills" || { err "clone failed"; exit 1; }
  for pair in $missing; do
    src="${pair%%:*}"; dst="${pair##*:}"
    cp -R "$tmp/skills/$src" "$SKILLS_DIR/$dst"
    ok "installed $dst  ($(find "$SKILLS_DIR/$dst" -name SKILL.md | wc -l | tr -d ' ') SKILL.md)"
  done
fi

echo
info "what the agent gains from 'apexlang':"
echo "    templates/region-components/*      canonical .apx for every region type (chart, IR, cards, …)"
echo "    assets/grammar/apexlang.ebnf       the language grammar"
echo "    tools/query-valid-props.mjs        compiler-backed: which properties/values does X accept?"
echo
info "skills load at agent start — restart the agent session to pick them up."
echo
echo "  Alternatives:"
echo "    Claude Code plugins : /plugin marketplace add oracle/skills  →  /plugin install apex@oracle-skills"
echo "    Other agents        : npx skills add oracle/skills/apex   (also …/db, …/oci)"
