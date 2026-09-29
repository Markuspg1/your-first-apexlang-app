#!/usr/bin/env bash
# Provision an Always Free Autonomous Database and download its wallet.
# Idempotent: if an ADB with the target display-name already exists and is
# AVAILABLE, we reuse it. Otherwise we provision fresh.
#
# Overridable env vars:
#   OCI_PROFILE     default: personal
#   OCI_REGION      default: the region of the OCI profile (set by oci session authenticate)
#   ADB_DISPLAY     default: WEBINAR-DEMO
#   ADB_DB_NAME     default: WEBINAR
#   ADB_DB_VERSION  default: 19c
set -u
. "$(dirname "$0")/_lib.sh"

PROFILE="${OCI_PROFILE:-personal}"
REGION=$(oci_region "$PROFILE")
[ -n "$REGION" ] || { err "no region: set OCI_REGION=<your home region> or run scripts/06-auth-oci.sh first"; exit 1; }
DISPLAY="${ADB_DISPLAY:-WEBINAR-DEMO}"
DB_NAME="${ADB_DB_NAME:-WEBINAR}"
DB_VER="${ADB_DB_VERSION:-19c}"

export OCI_CLI_AUTH=security_token

if ! have oci; then err "oci CLI not installed"; exit 1; fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ADMIN_PW_FILE="$HERE/.adb-admin-password"
WALLET_PW_FILE="$HERE/.wallet-password"
DB_ID_FILE="$HERE/.adb-ocid"
WALLET_ZIP="$HERE/wallet.zip"
WALLET_DIR="$HERE/wallet"

TENANCY=$(awk -F= "/^\[$PROFILE\]/{f=1} f && /^tenancy/{print \$2; exit}" ~/.oci/config)
[ -z "$TENANCY" ] && { err "tenancy OCID not found in ~/.oci/config for profile $PROFILE"; exit 1; }
info "tenancy: $TENANCY"

# Look for an existing ADB with our display name
EXISTING=$(oci db autonomous-database list --profile "$PROFILE" --region "$REGION" \
  --compartment-id "$TENANCY" --query "data[?\"display-name\"==\`$DISPLAY\` && \"lifecycle-state\"==\`AVAILABLE\`] | [0].id" \
  --raw-output 2>/dev/null)

if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
  ok "existing AVAILABLE ADB '$DISPLAY' found — reusing"
  DB_ID="$EXISTING"
else
  # Generate + stash admin password (12–30 chars, mixed case + digit, no ")
  ADMIN_PW="Wbn$(openssl rand -hex 10)Aa1"
  printf '%s' "$ADMIN_PW" > "$ADMIN_PW_FILE" && chmod 600 "$ADMIN_PW_FILE"
  info "ADMIN password saved to $ADMIN_PW_FILE (mode 600)"

  info "provisioning $DISPLAY ($DB_VER, Always Free)…"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    result=$(oci db autonomous-database create \
      --profile "$PROFILE" --region "$REGION" \
      --compartment-id "$TENANCY" \
      --db-name "$DB_NAME" \
      --display-name "$DISPLAY" \
      --admin-password "$ADMIN_PW" \
      --cpu-core-count 1 \
      --data-storage-size-in-tbs 1 \
      --is-free-tier true \
      --db-version "$DB_VER" \
      --query 'data.id' --raw-output 2>&1)
    if echo "$result" | grep -q '^ocid1'; then
      DB_ID="$result"
      break
    fi
    if echo "$result" | grep -qi 'quota'; then
      warn "adb-free-count quota not released yet (attempt $attempt/10) — waiting 60s"
      sleep 60
    else
      err "unexpected error:"; echo "$result" | head -20; exit 1
    fi
  done
  [ -z "${DB_ID:-}" ] && { err "provision never accepted after 10 attempts"; exit 1; }

  info "provision accepted. OCID: $DB_ID"
  info "waiting for AVAILABLE…"
  for i in $(seq 1 45); do
    state=$(oci db autonomous-database get --profile "$PROFILE" --region "$REGION" \
      --autonomous-database-id "$DB_ID" --query 'data."lifecycle-state"' --raw-output 2>&1)
    case "$state" in
      AVAILABLE) ok "AVAILABLE"; break ;;
      FAILED|TERMINATED|UNAVAILABLE) err "reached bad state: $state"; exit 1 ;;
    esac
    printf "  %s  attempt %2d  state=%s\n" "$(date +%H:%M:%S)" "$i" "$state"
    sleep 20
  done
fi

printf '%s' "$DB_ID" > "$DB_ID_FILE"
ok "ADB OCID saved to $DB_ID_FILE"

# Wallet
WALLET_PW="Wal$(openssl rand -hex 10)Aa1"
printf '%s' "$WALLET_PW" > "$WALLET_PW_FILE" && chmod 600 "$WALLET_PW_FILE"

info "downloading wallet…"
rm -f "$WALLET_ZIP"
oci db autonomous-database generate-wallet --profile "$PROFILE" --region "$REGION" \
  --autonomous-database-id "$DB_ID" --password "$WALLET_PW" \
  --file "$WALLET_ZIP" 2>&1 | tail -3
mkdir -p "$WALLET_DIR"
unzip -oq "$WALLET_ZIP" -d "$WALLET_DIR"
ok "wallet unzipped to $WALLET_DIR"

echo
oci db autonomous-database get --profile "$PROFILE" --region "$REGION" \
  --autonomous-database-id "$DB_ID" --output json 2>&1 | \
  python3 -c "import sys,json; d=json.load(sys.stdin)['data']; \
    print('APEX URL       :', d['connection-urls']['apex-url']); \
    print('Developer URL  :', d['connection-urls']['ords-url']+'apex/'); \
    print('SQL-Dev URL    :', d['connection-urls']['sql-dev-web-url']); \
    print('DB name        :', d['db-name']); \
    print('Version        :', d['db-version']); \
    print('ORDS version   :', d.get('apex-details',{}).get('ords-version','?'))"
