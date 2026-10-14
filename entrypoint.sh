#!/bin/bash
set -e

# Resolve which agent to run, and build its command. Validated up front so we
# don't start dockerd for an invalid request. Any extra args passed to the
# container are forwarded to the agent.
case "$AGENT" in
    codex)
        set -- codex -s danger-full-access -a on-request "$@"
        ;;
    claude)
        set -- claude --dangerously-skip-permissions "$@"
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

# Rootless Docker-in-Docker: dockerd runs as this unprivileged user via
# rootlesskit (user namespaces + slirp4netns + fuse-overlayfs). The container
# has no --privileged and the daemon never holds host root, so the agent can
# build and run containers without being able to escape the sandbox.
#
# We invoke rootlesskit + dockerd directly, mirroring the official
# docker:dind-rootless entrypoint, rather than dockerd-rootless.sh: that script
# enables RootlessKit's detach-netns mode and runs a `sysctl net.ipv4.ip_forward`
# step that is rejected inside an unprivileged container. dockerd has built-in
# rootless support and configures the network namespace itself.
# Select FUSE explicitly: Docker 29's default containerd overlayfs snapshotter
# can fail to mount layers inside a nested container.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.local/share/docker"
chmod 700 "$XDG_RUNTIME_DIR"

# Redirect stdin too, not just stdout/stderr: otherwise the whole rootlesskit ->
# dockerd -> containerd tree inherits our TTY on fd 0. Job control is off in a
# script, so `&` leaves the daemon in the foreground process group, where reads
# from the terminal succeed instead of raising SIGTTIN. It steals bytes, and the
# TUI agent inserts the truncated escape sequences as literal text
# ("[I5;121;5M..."). Keep both: setsid removes the controlling terminal (also
# for nested containers), </dev/null keeps fd 0 off the TTY.
setsid rootlesskit \
    --net=slirp4netns \
    --mtu=1500 \
    --disable-host-loopback \
    --port-driver=builtin \
    --copy-up=/etc \
    --copy-up=/run \
    dockerd --host="$DOCKER_HOST" \
        --feature containerd-snapshotter=false \
        --storage-driver=fuse-overlayfs </dev/null > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!

# Wait for the socket. If dockerd dies during boot, surface the log and exit.
# $! is still the daemon: job control is off, so setsid execs in place, no fork.
# </dev/null so the CLI can never prompt on our TTY either.
while ! docker info </dev/null >/dev/null 2>&1; do
    if ! kill -0 "$DOCKERD_PID" 2>/dev/null; then
        echo "rootless dockerd exited during startup; last log lines:" >&2
        tail -n 50 /tmp/dockerd.log >&2 || true
        exit 1
    fi
    sleep 1
done
# stderr, to keep stdout clean for the TUI agent.
echo "Rootless Docker daemon is ready" >&2

if [ -d /workspace/.git ]; then
    git config --global --add safe.directory /workspace || true
fi

# dockerd's boot, a git/ssh prompt or a killed TUI can leave mouse reporting or
# bracketed paste enabled; the agent then gets escape sequences it never asked
# for and echoes the tail as text. Reset them, but only on a real terminal.
if [ -t 0 ]; then
    # mouse tracking, SGR encoding, focus events, bracketed paste
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1004l\033[?2004l'
    stty sane 2>/dev/null || true
fi

exec "$@"
