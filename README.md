# Agent Sandbox

A minimal Docker-based sandbox for running the OpenAI Codex CLI or Claude Code with Rust support.

## Features

- Rust toolchain (cargo, rustc)
- Node.js + npm
- Codex CLI and Claude Code preinstalled
- Non-root user setup (`agent`)
- Rootless Docker-in-Docker — the agent can build and run containers, with no
  `--privileged` and no path to host root
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

---

## Docker-in-Docker (rootless)

The agent has a full Docker engine inside the sandbox, running **rootless** as
the unprivileged `agent` user (rootlesskit + user namespaces + slirp4netns +
fuse-overlayfs). The container starts with **no `--privileged`**, so a compromised
agent cannot escape to the host.

It runs on the default bridge network, **not** `--network host`, so services on
the host's `127.0.0.1` are out of reach.

`just run` passes the flags rootless dockerd needs:

- `--security-opt seccomp=unconfined` — allow the namespace syscalls rootlesskit uses
- `--security-opt label=disable` — SELinux: don't confine the nested engine
- `--security-opt systempaths=unconfined` — let nested containers mount their own `/proc`
- `--device /dev/fuse` — storage driver (fuse-overlayfs)
- `--device /dev/net/tun` — userspace networking (slirp4netns)

The nested daemon's data lives in an anonymous volume at
`~/.local/share/docker` and is **not** persisted across runs (`--rm`).

### Requirements / notes
- Host kernel must allow unprivileged user namespaces (default on Fedora).
- The agent talks to the daemon via `DOCKER_HOST` (a per-user socket under
  `$XDG_RUNTIME_DIR`); `docker` just works inside the container.
- Rootless networking is userspace, so it is somewhat slower than a rootful
  bridge; fine for builds and most workloads.
