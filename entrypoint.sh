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
# rootless support and configures the netns/storage itself.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.local/share/docker"
chmod 700 "$XDG_RUNTIME_DIR"

rootlesskit \
    --net=slirp4netns \
    --mtu=1500 \
    --disable-host-loopback \
    --port-driver=builtin \
    --copy-up=/etc \
    --copy-up=/run \
    dockerd --host="$DOCKER_HOST" > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!

# Wait for the socket. If dockerd dies during boot, surface the log and exit.
while ! docker info >/dev/null 2>&1; do
    if ! kill -0 "$DOCKERD_PID" 2>/dev/null; then
        echo "rootless dockerd exited during startup; last log lines:" >&2
        tail -n 50 /tmp/dockerd.log >&2 || true
        exit 1
    fi
    sleep 1
done
echo "Rootless Docker daemon is ready"

if [ -d /workspace/.git ]; then
    git config --global --add safe.directory /workspace || true
fi

exec "$@"
