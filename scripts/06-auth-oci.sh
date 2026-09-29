#!/usr/bin/env bash
# Authenticate to OCI. Refresh existing session; browser-auth if none.
# Also exports OCI_CLI_AUTH=security_token so downstream CLI calls in this
# terminal use the session token instead of expecting an API key.
#
# Overridable env vars:
#   OCI_PROFILE   default: personal
#   OCI_REGION    default: none — `oci session authenticate` then prompts with the region list
set -u
. "$(dirname "$0")/_lib.sh"

PROFILE="${OCI_PROFILE:-personal}"
REGION="${OCI_REGION:-}"

if ! have oci; then
  err "oci CLI not installed — run scripts/02-install-oci-cli.sh first"
  exit 1
fi

TOKEN="$HOME/.oci/sessions/$PROFILE/token"

if [ -f "$TOKEN" ]; then
  ok "session found for profile '$PROFILE' — refreshing..."
  export OCI_CLI_AUTH=security_token
  if oci session refresh --profile "$PROFILE" 2>&1 | tail -5; then
    ok "session refreshed. Verifying with a tenancy call..."
    if oci iam region-subscription list --profile "$PROFILE" --output table 2>&1 | head -10; then
      info 'export OCI_CLI_AUTH=security_token   # add to your shell to keep this'
      exit 0
    fi
    warn "refresh succeeded but tenancy call failed — will re-authenticate"
  else
    warn "refresh failed — will re-authenticate"
  fi
fi

info "starting browser auth for profile '$PROFILE'${REGION:+ in region '$REGION'}..."
info "(a browser window will open; sign in, then this terminal will continue)"
info 'after auth completes, remember to: export OCI_CLI_AUTH=security_token'
if [ -n "$REGION" ]; then
  exec oci session authenticate --profile-name "$PROFILE" --region "$REGION"
else
  info "pick your tenancy HOME region from the list (Always Free ADBs live there)"
  exec oci session authenticate --profile-name "$PROFILE"
fi
