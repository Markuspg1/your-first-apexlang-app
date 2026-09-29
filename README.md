# Your First APEXlang App — From Nothing to Running

A live-webinar demo that takes an empty Mac to a running Oracle APEX 26.1 application on Oracle Cloud Always Free, terminal-only, in under an hour.

## What you'll build

A working APEX app deployed on an Autonomous Database you provisioned yourself, with a sample `sales` table + 20 rows, served at a public URL — all driven by a plain-English prompt to your coding agent.

## Prerequisites

- macOS 13+ (Ventura or newer) on Apple Silicon or Intel
- [Homebrew](https://brew.sh)
- A **personal** Oracle Cloud account with an Always Free ADB slot open (max 2 per tenancy). If you already have 2 running, terminate one and wait ~60s.
- A coding agent that can execute shell commands: [Antigravity](https://antigravity.google), [Claude Code](https://claude.com/claude-code), Cursor, or Aider

## Quick start

```bash
git clone https://github.com/Markuspg1/your-first-apexlang-app.git
cd your-first-apexlang-app

# 1–4: installs (idempotent — skips what you already have)
bash scripts/01-check-agent.sh
bash scripts/02-install-oci-cli.sh
bash scripts/03-install-sqlcl.sh
bash scripts/04-install-java21.sh

# 5: sign in to OCI (browser flow)
bash scripts/06-auth-oci.sh          # prompts for your tenancy's HOME region (or: OCI_REGION=<region> bash …)
export OCI_CLI_AUTH=security_token   # required for session-token profiles

# 5b: give your agent Oracle's official skills (APEXlang grammar + templates + tools)
bash scripts/06b-install-oracle-skills.sh   # then restart the agent session

# 6: provision Always Free ADB (or reuse one already named WEBINAR-DEMO)
bash scripts/07-provision-adb.sh

# 7: create WEBINAR schema + APEX workspace + admin user
bash scripts/08-setup-workspace.sh

# 8: validate + import + open the deployed app
bash scripts/09-deploy-app.sh
```

Total wall-clock time on a fresh Mac: **~15 minutes** (most of it downloading SQLcl, OCI CLI, and Java 21).

## Running the deck

The presentation is a single self-contained HTML file with optional "Run this in my terminal" buttons that fire the scripts above.

```bash
python3 bridge.py           # opens the deck + a target Terminal window
```

The bridge:
- Serves `presentation.html` at http://127.0.0.1:7777/
- Opens (or reuses) a Terminal.app / iTerm2 tab titled `webinar-demo`
- Sends each Run-button click to that tab via AppleScript

Slide navigation: `←` / `→`, `Space`, `Home` / `End`, `F` for fullscreen. Click the left or right third of the deck margin to advance. Clicking inside a code block or on a `Run` / `⎘` button doesn't advance the slide.

## Give your agent Oracle's own skills

Oracle publishes agent skills for APEXlang, SQLcl/Database and OCI at [github.com/oracle/skills](https://github.com/oracle/skills). In Claude Code:

```
/plugin marketplace add oracle/skills
/plugin install apex@oracle-skills
/plugin install db@oracle-skills
/plugin install oci@oracle-skills
```

The `apex` plugin ships the APEXlang grammar, canonical `.apx` templates for every region type, and `tools/query-valid-props.mjs`, which answers "what properties does X accept?" straight from the compiler metadata. See `AGENTS.md` for what's worth reading first.

## Region + tenancy overrides

All the OCI-touching scripts accept environment overrides so audience members with different home regions can run the same repo:

```bash
OCI_PROFILE=personal           # ~/.oci/config profile name
OCI_REGION=us-phoenix-1        # your tenancy HOME region; default = region saved in the OCI profile by 06-auth-oci.sh
ADB_DISPLAY=WEBINAR-DEMO       # ADB display name
ADB_DB_NAME=WEBINAR            # ADB internal db name (14 chars max)
ADB_DB_VERSION=19c             # 19c | 23ai | 26ai
```

## What's inside

```
scripts/    idempotent bash: install → auth → provision → workspace → deploy
projects/   APEXlang sample app (sales-dashboard) with a supporting-object install script
bridge.py   HTTP↔AppleScript bridge for the deck's Run buttons (macOS only)
presentation.html   the deck itself — works offline, no CDN
AGENTS.md   design notes + gotchas + APEXlang syntax discoveries
```

## Cleanup

To free the Always Free slot and delete everything this demo created:

```bash
export OCI_CLI_AUTH=security_token
DB_ID=$(cat .adb-ocid)
oci db autonomous-database delete --profile personal --region "$OCI_REGION" \
  --autonomous-database-id "$DB_ID" --force --wait-for-state SUCCEEDED
```

## About the author

**Marco Pereira** — Oracle APEX developer and AI integration expert based in College Station, Texas. Oracle ACE Associate, Kscope speaker, university professor, and consultant on Oracle APEX, E-Business Suite, Fusion, and Autonomous Database at Viscosity North America.

- Website and blog: [markuspg.com](https://markuspg.com) — articles, talks, and the webinar this repo was built for
- LinkedIn: [linkedin.com/in/marco-pereira-740022122](https://www.linkedin.com/in/marco-pereira-740022122/) — follow for APEX, APEXlang, and AI-agent posts
- GitHub: [github.com/Markuspg1](https://github.com/Markuspg1) — more demos and tooling
- Viscosity North America: [viscosityna.com](https://viscosityna.com) — Oracle consulting, the team behind this work
- OraPub: [orapub.com](https://www.orapub.com) — Oracle performance training and tooling, powered by Viscosity

If this saved you a night of `ORA-00001: unique constraint violated`, star the repo and say hi on LinkedIn. Questions, corrections, and pull requests welcome.

---

Built for the webinar *Your First APEXlang App — From Nothing to Running in a Single Session* · Marco Pereira · 2026
