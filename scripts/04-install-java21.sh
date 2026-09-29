#!/usr/bin/env bash
# Install OpenJDK 21 and wire JAVA_HOME so SQLcl's APEXlang compiler works.
# SQLcl 26.1 bundles Java 16; the APEXlang compiler needs Java 17+.
set -u
. "$(dirname "$0")/_lib.sh"

JDK_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

if [ -x "$JDK_HOME/bin/java" ]; then
  ok "openjdk@21 already installed: $("$JDK_HOME/bin/java" -version 2>&1 | head -1)"
else
  if ! have brew; then
    err "Homebrew is required. Install it first from https://brew.sh"
    exit 1
  fi
  info "installing openjdk@21 via Homebrew..."
  brew install openjdk@21
fi

# ~/.zshrc wiring (idempotent — only append if the exact export isn't already there)
JH_LINE="export JAVA_HOME=\"$JDK_HOME\""
PATH_LINE='export PATH="$JAVA_HOME/bin:$PATH"'

if grep -qF "$JH_LINE" "$HOME/.zshrc" 2>/dev/null; then
  ok "JAVA_HOME already exported in ~/.zshrc"
else
  info "appending JAVA_HOME + PATH to ~/.zshrc..."
  {
    echo ""
    echo "# Java 21 for SQLcl 26.1 APEXlang compiler (Oracle APEX 26.1)"
    echo "$JH_LINE"
    echo "$PATH_LINE"
  } >> "$HOME/.zshrc"
fi

# Export for the current shell so 'java -version' below reflects it right now.
export JAVA_HOME="$JDK_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

ok "current java: $(java -version 2>&1 | head -1)"
