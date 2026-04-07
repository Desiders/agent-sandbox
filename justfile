project := env_var_or_default("PROJECT", ".")

build:
    docker build \
        --build-arg USER_UID=$(id -u) \
        -t agent-sandbox .

run:
    docker run -it \
        --network host \
        --rm \
        -v "{{project}}":/workspace \
        -v ~/.cargo/registry:/home/agent/.cargo/registry \
        -v ~/.rustup:/home/agent/.rustup \
        -v ~/.codex:/home/agent/.codex \
        -w /workspace \
        agent-sandbox

up: build run

work path:
    PROJECT={{path}} just up

ps:
    docker ps --filter ancestor=agent-sandbox

stop:
    docker ps -q --filter ancestor=agent-sandbox | xargs -r docker stop

clean:
    docker rmi agent-sandbox
