#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 VERSION [INSTALL_DIRECTORY]" >&2
    exit 1
fi

just_version=$1
install_directory=${2:-/usr/local/bin}
if ! printf '%s\n' "$just_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Invalid just version: $just_version" >&2
    exit 1
fi

target_architecture=${TARGETARCH:-$(dpkg --print-architecture)}
case "$target_architecture" in
    amd64) release_target=x86_64-unknown-linux-musl ;;
    arm64) release_target=aarch64-unknown-linux-musl ;;
    *) echo "Unsupported just architecture: $target_architecture" >&2; exit 1 ;;
esac

archive="just-$just_version-$release_target.tar.gz"
release_url="https://github.com/casey/just/releases/download/$just_version"
download_directory=$(mktemp -d)
trap 'rm -rf -- "$download_directory"' 0
trap 'exit 1' HUP INT TERM

curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
    "$release_url/$archive" -o "$download_directory/$archive"
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
    "$release_url/SHA256SUMS" -o "$download_directory/SHA256SUMS"

# Verify exactly one checksum for this architecture before extracting anything.
if ! awk -v archive="$archive" '
    $2 == archive { printf "%s  %s\n", $1, $2; matches++ }
    END { if (matches != 1) exit 1 }
' "$download_directory/SHA256SUMS" > "$download_directory/checksum"; then
    echo "Missing or ambiguous checksum for $archive" >&2
    exit 1
fi
(cd "$download_directory" && sha256sum --check --strict checksum)

tar -xzf "$download_directory/$archive" -C "$download_directory" \
    --no-same-owner just
install -d "$install_directory"
install -m 0755 "$download_directory/just" "$install_directory/just"
