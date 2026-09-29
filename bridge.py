#!/usr/bin/env python3
"""
Local HTTP bridge for the APEXlang webinar deck.

Serves presentation.html at http://127.0.0.1:7777 and accepts POST /run
requests that type the given command into your frontmost macOS terminal
(Terminal.app or iTerm2), so clicking "Run" on a slide fires the command
live in the terminal your audience is watching.

Usage:
    python3 bridge.py                  # auto-detect Terminal vs iTerm2
    python3 bridge.py --terminal iterm2
    python3 bridge.py --terminal terminal
    python3 bridge.py --port 7778 --no-open
    python3 bridge.py --dry-run        # log commands only, don't execute

Security:
    - Binds to 127.0.0.1 only (never network-accessible)
    - All commands are triggered by a human clicking a button on the slide
    - No shell escaping games: the command string is delivered verbatim to
      AppleScript which types it into the terminal
"""

import argparse
import http.server
import json
import socketserver
import subprocess
import threading
import urllib.parse
import webbrowser
from pathlib import Path

HERE = Path(__file__).parent.resolve()
HTML_FILE = HERE / "presentation.html"


def detect_terminal() -> str:
    """Return 'iterm2' or 'terminal'. Prefer whichever is frontmost or running."""
    try:
        r = subprocess.run(
            ["osascript", "-e",
             'tell application "System Events" to name of first process whose frontmost is true'],
            capture_output=True, text=True, timeout=3,
        )
        name = r.stdout.strip()
        if name in ("iTerm2", "iTerm"):
            return "iterm2"
        if name == "Terminal":
            return "terminal"
    except Exception:
        pass
    try:
        r = subprocess.run(
            ["osascript", "-e", 'application "iTerm" is running'],
            capture_output=True, text=True, timeout=3,
        )
        if r.stdout.strip() == "true":
            return "iterm2"
    except Exception:
        pass
    return "terminal"


def _osa(script: str, timeout: int = 10):
    r = subprocess.run(["osascript", "-e", script],
                       capture_output=True, text=True, timeout=timeout)
    return r.returncode == 0, r.stdout, r.stderr


def ensure_target_window(terminal: str, title: str, workdir: str = ""):
    """Create the named target window if it doesn't already exist.

    New windows cd into `workdir` (default: presentation directory) so
    `bash scripts/xxx.sh` just works.
    """
    if not workdir:
        workdir = str(HERE)
    workdir_esc = workdir.replace("\\", "\\\\").replace('"', '\\"')

    if terminal == "iterm2":
        script = f'''
        tell application "iTerm"
          activate
          set found to false
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if name of s is "{title}" then set found to true
              end repeat
            end repeat
          end repeat
          if not found then
            create window with default profile
            tell current session of current window
              set name to "{title}"
              write text "cd \\"{workdir_esc}\\" && clear"
            end tell
          end if
        end tell
        '''
    else:
        script = f'''
        tell application "Terminal"
          activate
          set found to false
          repeat with w in windows
            repeat with t in tabs of w
              try
                if custom title of t is "{title}" then set found to true
              end try
            end repeat
          end repeat
          if not found then
            set newTab to do script "cd \\"{workdir_esc}\\" && clear"
            set custom title of newTab to "{title}"
          end if
        end tell
        '''
    return _osa(script)


def type_into_terminal(cmd: str, terminal: str, title: str, dry_run: bool = False):
    """Type `cmd` into the named target window ('{title}'), creating it if needed."""
    if dry_run:
        return True, f"[dry-run] would type into '{title}': {cmd}", ""

    ensure_target_window(terminal, title)
    esc = cmd.replace("\\", "\\\\").replace('"', '\\"')

    if terminal == "iterm2":
        script = f'''
        tell application "iTerm"
          activate
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if name of s is "{title}" then
                  select w
                  tell t to select
                  tell s
                    select
                    write text "{esc}"
                  end tell
                  return
                end if
              end repeat
            end repeat
          end repeat
        end tell
        '''
    else:
        script = f'''
        tell application "Terminal"
          activate
          repeat with w in windows
            repeat with t in tabs of w
              try
                if custom title of t is "{title}" then
                  set frontmost of w to true
                  set selected of t to true
                  do script "{esc}" in t
                  return
                end if
              end try
            end repeat
          end repeat
        end tell
        '''
    return _osa(script)


class Handler(http.server.SimpleHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ("/", "/presentation.html"):
            if not HTML_FILE.exists():
                self._json(500, {"error": f"missing {HTML_FILE}"})
                return
            body = HTML_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self._cors()
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path == "/health":
            self._json(200, {
                "ok": True,
                "terminal": self.server.terminal,  # type: ignore[attr-defined]
                "target": self.server.target,      # type: ignore[attr-defined]
                "dry_run": self.server.dry_run,    # type: ignore[attr-defined]
            })
            return
        self.send_response(404); self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/run":
            self._json(404, {"error": "not found"}); return
        length = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(length) or b"{}")
        except Exception as e:
            self._json(400, {"error": f"bad json: {e}"}); return
        cmd = (data.get("cmd") or "").strip()
        if not cmd:
            self._json(400, {"error": "empty command"}); return
        term = self.server.terminal              # type: ignore[attr-defined]
        target = self.server.target              # type: ignore[attr-defined]
        dry = self.server.dry_run                # type: ignore[attr-defined]
        print(f"→ RUN [{term}:{target}{' dry' if dry else ''}]: {cmd}", flush=True)
        ok, out, err = type_into_terminal(cmd, term, target, dry_run=dry)
        self._json(200 if ok else 500, {"ok": ok, "stdout": out, "stderr": err})

    def log_message(self, fmt, *args):
        # quiet default access log; we print our own RUN lines
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=7777)
    ap.add_argument("--terminal", choices=["auto", "terminal", "iterm2"], default="auto")
    ap.add_argument("--target-title", default="webinar-demo",
                    help="Custom title of the terminal tab to type commands into "
                         "(created on startup if missing)")
    ap.add_argument("--no-open", action="store_true", help="don't auto-open the browser")
    ap.add_argument("--dry-run", action="store_true", help="log commands but don't execute")
    args = ap.parse_args()

    term = detect_terminal() if args.terminal == "auto" else args.terminal
    url = f"http://127.0.0.1:{args.port}/"

    class ReusableTCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    with ReusableTCPServer(("127.0.0.1", args.port), Handler) as httpd:
        httpd.terminal = term            # type: ignore[attr-defined]
        httpd.target = args.target_title # type: ignore[attr-defined]
        httpd.dry_run = args.dry_run     # type: ignore[attr-defined]
        print(f"webinar bridge listening on {url}")
        print(f"target: {term} window titled '{args.target_title}'{' (dry-run)' if args.dry_run else ''}")
        if not args.dry_run:
            print("creating target window if missing...")
            ensure_target_window(term, args.target_title)
        print("Ctrl-C to stop.")
        if not args.no_open:
            threading.Timer(0.3, lambda: webbrowser.open(url)).start()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nbye")


if __name__ == "__main__":
    main()
