#!/bin/bash
set -e

if [ -d /workspace/.git ]; then
    git config --global --add safe.directory /workspace || true
fi

case "$AGENT" in
    codex)
        exec codex -s danger-full-access -a on-request "$@"
        ;;
    claude)
        exec claude --dangerously-skip-permissions "$@"
        ;;
    "")
        echo "AGENT is required (set to 'codex' or 'claude')" >&2
        exit 1
        ;;
    *)
        echo "Unknown AGENT '$AGENT' (expected 'codex' or 'claude')" >&2
        exit 1
        ;;
esac
