# Agent Sandbox

A minimal Docker-based sandbox for running the OpenAI Codex CLI or Claude Code with Rust support.

## Features

- Rust toolchain (cargo, rustc)
- Node.js + npm
- Codex CLI and Claude Code preinstalled
- Non-root user setup (`agent`)
- Persistent caches for:
  - Cargo registry
  - Rustup toolchains
  - Codex config
  - Claude Code config
- `just` command runner for easy workflows

---

## Requirements

- Docker
- `just` (optional but recommended)

Install `just`:
```bash
cargo install just
```

---

## Run command

The agent to run is required — pass `codex` or `claude`:
```bash
just work /absolute/path/to/project codex
just work /absolute/path/to/project claude
```

---

## Other commands

```bash
just ps
just stop
just clean
```

---

## Persistent Volumes
The container mounts:
- `~/.cargo/registry` → Cargo cache
- `~/.rustup` → Rust toolchains
- `~/.codex` → Codex config
- `~/.claude` + `~/.claude.json` → Claude Code config

This avoids re-downloading dependencies.
