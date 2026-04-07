#!/bin/bash
set -e

if [ -d /workspace/.git ]; then
    git config --global --add safe.directory /workspace || true
fi

exec codex -s danger-full-access -a on-request
