# Agent Sandbox

Run Codex or Claude Code in a Docker image suited to your project.

## Requirements

- Docker with BuildKit and `just` (`cargo install just`)
- Linux with unprivileged user namespaces, `/dev/fuse`, and `/dev/net/tun`

## Usage

Choose `rust` or `node`:

```bash
just work rust /absolute/path/to/project codex
just work node /absolute/path/to/project claude
```

Each image has its own Dockerfile and tag (`agent-sandbox:rust` or
`agent-sandbox:node`). Both include the agents, Git, Python, and rootless Docker.
Both use Node.js 24 for the agents; the Rust image also includes Rust 1.95.
Codex runs with full access inside the container and approval prompts disabled
(`-s danger-full-access -a never`).
Codex startup update checks and Claude automatic updates are disabled in the
container. Agent versions are pinned in the Dockerfiles; change those pins and
rebuild to update them.

```bash
just build rust      # build one image
just rebuild rust    # refresh packages without reusing image layers
just run rust codex  # run it in the current project
just ps              # list all running sandboxes
just stop            # stop them
just clean node      # remove one image
```

Builds cache APT/npm downloads and pin base images, agent CLIs, and `just`.
Changing your UID or the entrypoint preserves the tool-installation cache.

## Optional Rust cache

Kache is off by default and applies only to the Rust image:

```bash
KACHE=1 just work rust /absolute/path/to/project codex
```

This installs and configures Kache and mounts the existing host `~/.cache/kache`.
For separate `build` and `run` commands, use `KACHE=1` for both.

On the host, [install Kache](https://kunobi.ninja/docs/kache/getting-started/installation)
and run `kache init` once to configure Cargo. Then use `kache config` to set
the filesystem remote below and press `s` to save. This creates
`~/.config/kache/config.toml` (or `$XDG_CONFIG_HOME/kache/config.toml`):

```toml
[cache.remote]
type = "filesystem"
path = "~/.cache/kache"
prefix = "artifacts"
```

Run `kache sync --push` to share artifacts already cached on the host.
Then use Cargo normally. Hits require matching Rust toolchains, targets, and
build settings. Run `kache daemon stop` before leaving the sandbox to finish uploads.
For a custom directory, set `KACHE_SHARED_DIR` to an absolute path and use it in the host config.

The Rust image creates agent-owned local cache directories before Docker mounts
the shared cache. Older images can have a root-owned `/home/agent/.cache`, causing
Kache to fail with `Permission denied` when creating its local cache index.
Rebuild with `KACHE=1 just build rust` and start a new sandbox to apply the fix.

## Persistent data

Both images mount the project at `/workspace` and reuse host Codex/Claude settings.
Only Rust mounts the host Cargo registry; each image manages its own toolchain.
Host settings and cache paths must already exist.
Nested Docker containers and images are discarded when the sandbox exits.
