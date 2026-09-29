#!/usr/bin/env bash
# Print every URL and credential the demo created, read from the local dot-files
# (never committed). Safe to run any time; called automatically at the end of
# 08-setup-workspace.sh and 09-deploy-app.sh.
set -u
. "$(dirname "$0")/_lib.sh"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${OCI_PROFILE:-personal}"
export OCI_CLI_AUTH=security_token

rd() { [ -f "$HERE/$1" ] && cat "$HERE/$1" || printf '(not yet — run %s)' "$2"; }

ORDS=""
if [ -f "$HERE/.adb-ocid" ] && have oci; then
  REGION=$(oci_region "$PROFILE")
  [ -n "$REGION" ] && ORDS=$(oci db autonomous-database get --profile "$PROFILE" --region "$REGION" \
      --autonomous-database-id "$(cat "$HERE/.adb-ocid")" \
      --query 'data."connection-urls"."ords-url"' --raw-output 2>/dev/null)
fi
[ -n "$ORDS" ] || ORDS="https://<adb-host>/ords/   (run 07-provision-adb.sh) "

echo "=================================================================="
echo "  APEX BUILDER LOGIN  — open the app in App Builder / Page Designer"
echo "=================================================================="
echo "  URL       : ${ORDS}apex/"
echo "  Workspace : WEBINAR"
echo "  Username  : ADMIN"
echo "  Password  : $(rd .webinar-admin-web-password 08-setup-workspace.sh)"
echo
echo "  Deployed app (public, no login):"
echo "    ${ORDS}r/webinar/sales-dashboard/"
echo "    (alias gets a numeric suffix, e.g. sales-dashboard102, if you import more than once)"
echo
echo "  Database Actions / SQL Developer Web: ${ORDS}sql-developer"
echo "    ADMIN   / $(rd .adb-admin-password 07-provision-adb.sh)   (DBA)"
echo "    WEBINAR / $(rd .webinar-schema-password 08-setup-workspace.sh)   (app schema)"
echo
echo "  SQLcl: sql -cloudconfig $HERE/wallet.zip webinar/<schema pw>@webinar_medium"
echo "  Wallet password: $(rd .wallet-password 07-provision-adb.sh)"
echo "=================================================================="
