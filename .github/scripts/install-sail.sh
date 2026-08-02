#!/usr/bin/env bash
#
# Install the Sail RISC-V reference model (sail_riscv_sim) for CI.
# Downloads a pinned sail-riscv prebuilt tarball into $HOME/tools/sail
# and adds it to PATH.
#
# Pin via env: SAIL_VERSION (default below).

set -euo pipefail

VERSION="${SAIL_VERSION:-0.10}"
PREFIX="$HOME/tools/sail"
URL="https://github.com/riscv/sail-riscv/releases/download/${VERSION}/sail-riscv-$(uname)-$(arch).tar.gz"

if [ -x "$PREFIX/bin/sail_riscv_sim" ]; then
    echo "Sail $VERSION already installed at $PREFIX"
else
    mkdir -p "$PREFIX"
    echo "Downloading $URL"
    curl --location --silent --show-error "$URL" \
        | tar xz --directory="$PREFIX" --strip-components=1
fi

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$PREFIX/bin" >> "$GITHUB_PATH"
fi

"$PREFIX/bin/sail_riscv_sim" --version | head -n1
