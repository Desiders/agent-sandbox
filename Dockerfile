FROM rust:slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git \
    pkg-config libssl-dev \
    ca-certificates \
    nodejs npm \
    python3 python3-pip python3-venv python3-dev \
    build-essential \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

ARG USER_UID=1000
RUN useradd -m -u ${USER_UID} -s /bin/bash agent

RUN npm install -g @openai/codex @anthropic-ai/claude-code

RUN curl --proto '=https' --tlsv1.2 -sSf \
    https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Docker engine in rootless mode, for unprivileged Docker-in-Docker.
# docker-ce-rootless-extras brings rootlesskit; uidmap provides the setuid
# newuidmap/newgidmap; slirp4netns gives userspace networking and
# fuse-overlayfs the storage driver. Together these let dockerd run as the
# unprivileged `agent` user with no --privileged and no path to host root.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        uidmap \
        slirp4netns \
        fuse-overlayfs \
        iproute2 \
        procps \
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Subordinate UID/GID ranges so the agent user can map nested user namespaces.
# useradd may already allocate a range; overwrite to a single clean entry.
RUN printf 'agent:100000:65536\n' > /etc/subuid \
    && printf 'agent:100000:65536\n' > /etc/subgid

# Debian ships newuidmap/newgidmap setuid-root, which makes them run as euid 0.
# The kernel's verify_root_map then rejects the rootless mapping (it maps the
# child's uid 0 to the agent's real uid, which must match the caller's euid).
# Give them file capabilities and drop the setuid bit so they keep uid != 0
# while still being able to write the id maps.
RUN setcap cap_setuid+ep /usr/bin/newuidmap \
    && setcap cap_setgid+ep /usr/bin/newgidmap \
    && chmod u-s /usr/bin/newuidmap /usr/bin/newgidmap

ENV HOME=/home/agent
WORKDIR /workspace

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R ${USER_UID}:${USER_UID} /workspace /entrypoint.sh ${HOME}

ENV PATH="/usr/local/cargo/bin:${PATH}"
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup

RUN ln -s /usr/local/cargo/bin/cargo /usr/bin/cargo \
 && ln -s /usr/local/cargo/bin/rustc /usr/bin/rustc

RUN chown -R ${USER_UID}:${USER_UID} /usr/local/cargo /usr/local/rustup

# Rootless runtime dir (mode 700, owned by the agent) and the data root, both
# owned by the agent user that runs dockerd.
RUN mkdir -p /run/user/${USER_UID} /home/agent/.local/share/docker \
    && chown -R ${USER_UID}:${USER_UID} /run/user/${USER_UID} /home/agent/.local \
    && chmod 700 /run/user/${USER_UID}

# The agent's docker CLI talks to the rootless daemon over this socket.
ENV XDG_RUNTIME_DIR=/run/user/${USER_UID}
ENV DOCKER_HOST=unix:///run/user/${USER_UID}/docker.sock

# Avoid overlay-on-overlay: back the rootless data root with an anonymous
# volume so it isn't itself an overlay layer of the outer container.
VOLUME /home/agent/.local/share/docker

# Run as the unprivileged agent user. dockerd runs rootless, so nothing in the
# container ever needs (or can reach) host root.
USER ${USER_UID}
ENTRYPOINT ["/entrypoint.sh"]
