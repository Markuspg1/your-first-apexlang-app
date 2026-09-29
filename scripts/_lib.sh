# shared helpers — sourced by every script
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[1;34m→\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*"; }

# Returns 0 if $1 is runnable. External commands must resolve to an executable
# file (this catches broken symlinks like a dead Antigravity install). Shell
# builtins and functions are trusted as-is.
have() {
  local path
  path=$(command -v "$1" 2>/dev/null) || return 1
  case "$path" in
    /*) [ -x "$path" ] ;;
    *)  return 0 ;;
  esac
}

# Region for an OCI profile: $OCI_REGION if set, else the profile's region= in ~/.oci/config
# (written there by `oci session authenticate`). Prints nothing if neither is known.
oci_region() {
  if [ -n "${OCI_REGION:-}" ]; then printf '%s' "$OCI_REGION"; return; fi
  awk -v p="[$1]" '$0==p{f=1;next} /^\[/{f=0} f && /^region[ \t]*=/{sub(/^region[ \t]*=[ \t]*/,""); print; exit}' "$HOME/.oci/config" 2>/dev/null
}
