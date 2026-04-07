# Agent Sandbox

A minimal Docker-based sandbox for running the OpenAI Codex CLI with Rust support.

## Features

- Rust toolchain (cargo, rustc)
- Node.js + npm
- Codex CLI preinstalled
- Non-root user setup (`agent`)
- Persistent caches for:
  - Cargo registry
  - Rustup toolchains
  - Codex config
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
```bash
just work path=/absolute/path/to/project
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

This avoids re-downloading dependencies.
