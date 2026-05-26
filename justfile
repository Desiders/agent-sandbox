project := env_var_or_default("PROJECT", ".")

build:
    docker build \
        --build-arg USER_UID=$(id -u) \
        -t agent-sandbox .

run agent:
    docker run -it \
        --network host \
        --rm \
        --init \
        --security-opt seccomp=unconfined \
        --security-opt label=disable \
        --security-opt systempaths=unconfined \
        --device /dev/fuse \
        --device /dev/net/tun \
        -e AGENT={{agent}} \
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
