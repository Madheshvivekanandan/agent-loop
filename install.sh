#!/usr/bin/env sh
# Install the agent-loop skill into a host's skills directory.
# Usage: ./install.sh <host> [--global] [--target <dir>]
#   host: claude-code | codex | cursor | agents
set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HOST=${1:-}
GLOBAL=0
TARGET=""

shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case $1 in
    --global) GLOBAL=1 ;;
    --target) TARGET=${2:?--target needs a directory}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

usage() {
  cat >&2 <<'USAGE'
Usage: ./install.sh <host> [--global] [--target <dir>]

Hosts:
  claude-code   .claude/skills/ + .claude/agents/   (native subagents, tool restriction)
  codex         .agents/skills/
  cursor        .cursor/skills/
  agents        .agents/skills/   shared convention; works in Codex, Cursor, VS Code, OpenCode, ...

Options:
  --global      install for the user instead of the current project
  --target DIR  install into DIR instead of a host default

Any other Agent Skills client: copy skills/agent-loop/ into its skills directory.
See https://agentskills.io/clients
USAGE
  exit 2
}

[ -n "$HOST" ] || usage

if [ -n "$TARGET" ]; then
  SKILLS=$TARGET
  AGENTS=""
else
  [ "$GLOBAL" -eq 1 ] && BASE=$HOME || BASE=$(pwd)
  case $HOST in
    claude-code) SKILLS="$BASE/.claude/skills"; AGENTS="$BASE/.claude/agents" ;;
    codex|agents) SKILLS="$BASE/.agents/skills"; AGENTS="" ;;
    cursor)      SKILLS="$BASE/.cursor/skills"; AGENTS="" ;;
    *) echo "unknown host: $HOST" >&2; usage ;;
  esac
fi

mkdir -p "$SKILLS"
rm -rf "$SKILLS/agent-loop"
cp -R "$SRC/skills/agent-loop" "$SKILLS/agent-loop"
echo "installed skill  -> $SKILLS/agent-loop"

if [ -n "$AGENTS" ]; then
  mkdir -p "$AGENTS"
  for a in "$SRC"/agents/*.md; do cp "$a" "$AGENTS/"; done
  echo "installed agents -> $AGENTS/ (5 stage agents)"
else
  echo "note: $HOST has no declarative subagents — the loop will run in Mode B or"
  echo "      request subagents at runtime, with diff-fingerprint verification."
fi

# Run artifacts are local audit logs, not source. Keep them out of git.
if [ "$GLOBAL" -eq 0 ] && [ -z "$TARGET" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  if ! grep -qx '\.agent-loop/' .gitignore 2>/dev/null; then
    printf '.agent-loop/\n' >> .gitignore
    echo "added .agent-loop/ to .gitignore"
  fi
fi

echo
echo "Invoke with: /agent-loop <task description>"
