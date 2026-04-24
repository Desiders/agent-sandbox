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

RUN npm install -g @openai/codex

RUN curl --proto '=https' --tlsv1.2 -sSf \
    https://just.systems/install.sh | bash -s -- --to /usr/local/bin

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

USER ${USER_UID}
ENTRYPOINT ["/entrypoint.sh"]
