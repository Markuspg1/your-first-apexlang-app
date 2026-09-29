#!/usr/bin/env bash
# Validate + import an APEXlang project into the WEBINAR workspace, then
# open the deployed app URL in the default browser.
#
# Args (all optional):
#   $1  path to the APEXlang project directory (default: ./projects/starter-app)
set -u
. "$(dirname "$0")/_lib.sh"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${1:-$HERE/projects/sales-dashboard}"
DB_ID_FILE="$HERE/.adb-ocid"
SCHEMA_PW_FILE="$HERE/.webinar-schema-password"
WALLET="$HERE/wallet.zip"

[ -d "$PROJECT" ]     || { err "project dir not found: $PROJECT"; exit 1; }
[ -f "$SCHEMA_PW_FILE" ] || { err "run 08-setup-workspace.sh first"; exit 1; }
[ -f "$DB_ID_FILE" ]  || { err "run 07-provision-adb.sh first"; exit 1; }
have sql              || { err "sqlcl not installed"; exit 1; }
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"

SCHEMA_PW=$(cat "$SCHEMA_PW_FILE")
DB_ID=$(cat "$DB_ID_FILE")
PROFILE="${OCI_PROFILE:-personal}"
REGION=$(oci_region "$PROFILE")
[ -n "$REGION" ] || { err "no region: set OCI_REGION=<your home region> or run scripts/06-auth-oci.sh first"; exit 1; }

info "validating APEXlang project at $PROJECT…"
sql -nolog <<EOF | tail -6
apex validate -input $PROJECT
exit
EOF

INSTALL_SQL="$PROJECT/supporting-objects/install-scripts/sales-schema.sql"
if [ -f "$INSTALL_SQL" ]; then
  info "running supporting-objects install script (sales table + seed rows)…"
  sql -cloudconfig "$WALLET" -S "webinar/${SCHEMA_PW}@webinar_medium" @"$INSTALL_SQL" 2>&1 | tail -3
fi

info "importing into WEBINAR workspace as WEBINAR schema…"
sql -cloudconfig "$WALLET" -S "webinar/${SCHEMA_PW}@webinar_medium" <<EOF | tail -8
apex import -input $PROJECT
SELECT application_id, application_name, alias FROM apex_applications WHERE workspace = 'WEBINAR' ORDER BY application_id DESC FETCH FIRST 3 ROWS ONLY;
EXIT
EOF

# Look up the newly-deployed app's alias + build the friendly URL
export OCI_CLI_AUTH=security_token
ORDS=$(oci db autonomous-database get --profile "$PROFILE" --region "$REGION" \
  --autonomous-database-id "$DB_ID" \
  --query 'data."connection-urls"."ords-url"' --raw-output 2>&1)
ALIAS=$(sql -cloudconfig "$WALLET" -S "webinar/${SCHEMA_PW}@webinar_medium" <<'EOF' 2>&1 | grep -oE '[a-z][a-z0-9_-]{2,}' | tail -1
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 SQLFORMAT DEFAULT
SELECT LOWER(alias) FROM apex_applications WHERE workspace = 'WEBINAR' ORDER BY application_id DESC FETCH FIRST 1 ROWS ONLY;
EXIT
EOF
)
APP_URL="${ORDS}r/webinar/${ALIAS}/"

echo
echo "=========================================="
echo "  DEPLOYED"
echo "=========================================="
echo "  Public app URL : $APP_URL"
echo "  Dev console    : ${ORDS}apex/"
echo "  Workspace      : WEBINAR"
echo "  Web admin      : admin  /  $(cat "$HERE/.webinar-admin-web-password")"
echo "=========================================="

if command -v open >/dev/null 2>&1; then
  info "opening $APP_URL"
  open "$APP_URL"
fi
