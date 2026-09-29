#!/usr/bin/env bash
# Create WEBINAR schema + APEX workspace + workspace admin user.
# Idempotent: drops+recreates schema; removes+re-adds workspace.
set -u
. "$(dirname "$0")/_lib.sh"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ADMIN_PW_FILE="$HERE/.adb-admin-password"
SCHEMA_PW_FILE="$HERE/.webinar-schema-password"
ADMIN_WEB_PW_FILE="$HERE/.webinar-admin-web-password"
WALLET="$HERE/wallet.zip"

[ -f "$ADMIN_PW_FILE" ] || { err "run 07-provision-adb.sh first"; exit 1; }
[ -f "$WALLET" ]        || { err "wallet not found — run 07-provision-adb.sh"; exit 1; }
have sql                || { err "sqlcl not installed — run 03-install-sqlcl.sh"; exit 1; }
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"

ADMIN_PW=$(cat "$ADMIN_PW_FILE")
SCHEMA_PW="Wbn$(openssl rand -hex 10)Aa1"
WEB_PW="WebAdmin$(openssl rand -hex 8)Aa1"
printf '%s' "$SCHEMA_PW" > "$SCHEMA_PW_FILE" && chmod 600 "$SCHEMA_PW_FILE"
printf '%s' "$WEB_PW"    > "$ADMIN_WEB_PW_FILE" && chmod 600 "$ADMIN_WEB_PW_FILE"

# Generate SQL with shell-substituted values (SQLcl heredocs mangle
# multi-line PL/SQL, so we always go through a temp file).
TMP_SQL=$(mktemp -t webinar-setup.XXXXXX.sql)
trap "rm -f $TMP_SQL" EXIT

cat > "$TMP_SQL" <<SQL
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

PROMPT === drop existing schema WEBINAR (idempotent) ===
BEGIN
  EXECUTE IMMEDIATE 'DROP USER WEBINAR CASCADE';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -1918 THEN RAISE; END IF;
END;
/

PROMPT === create schema WEBINAR ===
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER WEBINAR IDENTIFIED BY "${SCHEMA_PW}" QUOTA UNLIMITED ON DATA';
  EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE SESSION TO WEBINAR';
  DBMS_OUTPUT.PUT_LINE('schema WEBINAR created');
END;
/

PROMPT === remove any existing WEBINAR workspace ===
BEGIN
  APEX_INSTANCE_ADMIN.REMOVE_WORKSPACE(p_workspace => 'WEBINAR', p_drop_users => 'Y', p_drop_tables => 'Y');
  DBMS_OUTPUT.PUT_LINE('existing workspace removed');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('no existing workspace to remove (' || SQLCODE || ')');
END;
/

PROMPT === add workspace WEBINAR bound to schema WEBINAR ===
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(p_workspace_id => NULL, p_workspace => 'WEBINAR', p_primary_schema => 'WEBINAR');
  DBMS_OUTPUT.PUT_LINE('workspace WEBINAR added');
END;
/

PROMPT === create workspace admin user 'admin' ===
DECLARE v_web_pw VARCHAR2(200) := '${WEB_PW}';
BEGIN
  APEX_UTIL.SET_WORKSPACE(p_workspace => 'WEBINAR');
  EXECUTE IMMEDIATE 'BEGIN APEX_UTIL.CREATE_USER(p_user_name=>''ADMIN'', p_email_address=>''admin@webinar.local'', p_web_password=>:1, p_developer_privs=>''ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL'', p_change_password_on_first_use=>''N''); END;' USING v_web_pw;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('workspace admin ADMIN created');
END;
/

PROMPT === verify ===
SELECT workspace_id, workspace FROM apex_workspaces WHERE workspace = 'WEBINAR';
SELECT username FROM dba_users WHERE username = 'WEBINAR';

EXIT
SQL

info "running workspace bootstrap as ADMIN…"
sql -cloudconfig "$WALLET" -S "admin/${ADMIN_PW}@webinar_medium" @"$TMP_SQL"

ok "workspace ready"
echo
bash "$(dirname "$0")/10-show-credentials.sh"
