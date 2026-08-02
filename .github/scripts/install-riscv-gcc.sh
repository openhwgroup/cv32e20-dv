#!/usr/bin/env bash
#
# Install the RISC-V GCC toolchain (riscv64-unknown-elf-gcc) for CI.
# Downloads a pinned riscv-collab prebuilt tarball into $HOME/tools/riscv
# and exports CV_SW_TOOLCHAIN / CV_SW_PREFIX for the cv32e20-dv Make
# targets.
#
# Pin via env: RISCV_TOOLCHAIN_VERSION (default below).

set -euo pipefail

VERSION="${RISCV_TOOLCHAIN_VERSION:-2026.04.26}"
PREFIX="$HOME/tools/riscv"
URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${VERSION}/riscv64-elf-ubuntu-24.04-gcc.tar.xz"

if [ -x "$PREFIX/bin/riscv64-unknown-elf-gcc" ]; then
    echo "RISC-V GCC ${VERSION} already installed at $PREFIX"
else
    mkdir -p "$PREFIX"
    echo "Downloading $URL"
    curl --location --silent --show-error "$URL" \
        | tar xJ --directory="$PREFIX" --strip-components=1
fi

if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "CV_SW_TOOLCHAIN=$PREFIX"
        echo "CV_SW_PREFIX=riscv64-unknown-elf-"
    } >> "$GITHUB_ENV"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$PREFIX/bin" >> "$GITHUB_PATH"
fi

"$PREFIX/bin/riscv64-unknown-elf-gcc" --version | head -n1
