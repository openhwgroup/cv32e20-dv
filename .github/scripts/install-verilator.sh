#!/usr/bin/env bash
#
# Install Verilator from source for CI. Builds the pinned tag into
# $HOME/tools/verilator-<version> and adds it to PATH. The build is
# slow (~10 min); the workflow caches $PREFIX keyed on the version so
# subsequent runs skip the build entirely.
#
# Pin via env: VERILATOR_VERSION (default below).

set -euo pipefail

VERSION="${VERILATOR_VERSION:-v5.042}"
PREFIX="$HOME/tools/verilator-${VERSION}"

if [ -x "$PREFIX/bin/verilator" ]; then
    echo "Verilator $VERSION already installed at $PREFIX"
else
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        autoconf bison ccache flex g++ git help2man \
        libfl-dev libfl2 libjemalloc-dev make numactl \
        perl perl-doc python3 zlib1g zlib1g-dev

    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT

    git clone --depth 1 --branch "$VERSION" \
        https://github.com/verilator/verilator.git "$WORK/verilator"

    cd "$WORK/verilator"
    autoconf
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
fi

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$PREFIX/bin" >> "$GITHUB_PATH"
fi

"$PREFIX/bin/verilator" --version | head -n1
