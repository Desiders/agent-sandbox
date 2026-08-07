project := env_var_or_default("PROJECT", ".")

build:
    # Docker creates a directory for any missing mount source, which would turn
    # ~/.claude.json into a directory. Create the real paths first.
    touch ~/.claude.json
    mkdir -p ~/.claude ~/.codex ~/.cargo/registry ~/.rustup
    docker build \
        --build-arg USER_UID=$(id -u) \
        -t agent-sandbox .

run agent:
    # No --network host: it would give the agent the host's network namespace,
    # including everything on 127.0.0.1. The default bridge is enough.
    # -e TERM/-e COLORTERM forward the host's real terminal, so the agent emits
    # only escape sequences this terminal understands.
    docker run -it \
        --rm \
        --init \
        --security-opt seccomp=unconfined \
        --security-opt label=disable \
        --security-opt systempaths=unconfined \
        --device /dev/fuse \
        --device /dev/net/tun \
        -e AGENT={{agent}} \
        -e TERM \
        -e COLORTERM \
        -v "{{project}}":/workspace \
        -v ~/.cargo/registry:/home/agent/.cargo/registry \
        -v ~/.rustup:/home/agent/.rustup \
        -v ~/.codex:/home/agent/.codex \
        -v ~/.claude:/home/agent/.claude \
        -v ~/.claude.json:/home/agent/.claude.json \
        -w /workspace \
        agent-sandbox

up agent: build (run agent)

work path agent:
    PROJECT={{path}} just up {{agent}}

ps:
    docker ps --filter ancestor=agent-sandbox

stop:
    docker ps -q --filter ancestor=agent-sandbox | xargs -r docker stop

clean:
    docker rmi agent-sandbox
