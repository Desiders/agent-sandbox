project := absolute_path(env_var_or_default("PROJECT", "."))
kache := env_var_or_default("KACHE", "0")
kache_shared_dir := env_var_or_default("KACHE_SHARED_DIR", env_var("HOME") / ".cache/kache")

build image fresh="0":
    docker build {{if fresh == "1" { "--pull --no-cache" } else { "" }}} \
        --build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)" \
        {{if image == "rust" { "--build-arg INSTALL_KACHE=" + quote(kache) } else { "" }}} \
        -f Dockerfile.{{quote(image)}} -t agent-sandbox:{{quote(image)}} .

rebuild image:
    just build {{quote(image)}} 1

run image agent:
    #!/usr/bin/env bash
    set -euo pipefail
    args=()
    if [[ {{quote(image)}} == rust ]]; then
        args+=(--mount "type=bind,src=$HOME/.cargo/registry,dst=/usr/local/cargo/registry")
        if [[ {{quote(kache)}} == 1 ]]; then
            args+=(-e RUSTC_WRAPPER=kache -e KACHE_CONFIG=/etc/kache.toml)
            args+=(--mount type=bind,src={{quote(kache_shared_dir)}},dst=/home/agent/.cache/kache-shared)
        fi
    fi
    docker run -it --rm --init \
        --security-opt seccomp=unconfined \
        --security-opt label=disable \
        --security-opt systempaths=unconfined \
        --device /dev/fuse --device /dev/net/tun \
        -e AGENT={{quote(agent)}} -e TERM -e COLORTERM \
        --mount type=bind,src={{quote(project)}},dst=/workspace "${args[@]}" \
        --mount "type=bind,src=$HOME/.codex,dst=/home/agent/.codex" \
        --mount "type=bind,src=$HOME/.claude,dst=/home/agent/.claude" \
        --mount "type=bind,src=$HOME/.claude.json,dst=/home/agent/.claude.json" \
        -w /workspace agent-sandbox:{{quote(image)}}

up image agent: (build image) (run image agent)

work image path agent:
    PROJECT={{quote(path)}} just up {{quote(image)}} {{quote(agent)}}

ps:
    docker ps --filter label=org.desiders.agent-sandbox=true

stop:
    docker ps -q --filter label=org.desiders.agent-sandbox=true | xargs -r docker stop

clean image:
    docker rmi agent-sandbox:{{quote(image)}}
