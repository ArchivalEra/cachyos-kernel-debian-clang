#!/bin/bash
#
# Reproducible CachyOS kernel build for Debian, with BORE + clang ThinLTO + O3.
# SPDX-License-Identifier: AGPL-3.0-only
#
# Usage:
#   ./build-kernel.sh <major.minor> <tagrel> [pkgrel]
# Example:
#   ./build-kernel.sh 7.2.8 1 1
#
# Requirements:
#   clang/llvm/lld, ccache, pahole, dpkg-dev, debhelper, libssl-dev, etc.
#   See README.md for the toolchain layout this script was written against.
#
set -euo pipefail

VER="${1:?usage: build-kernel.sh <major.minor> <tagrel> [pkgrel]}"
TAGREL="${2:?usage: build-kernel.sh <major.minor> <tagrel> [pkgrel]}"
PKGREL="${3:-1}"

WORK="${WORK:-/mnt/hdd/buildstuff/cachyos-for-debian}"
SRC="${WORK}/src"
SRCNAME="cachyos-${VER}-${TAGREL}"
PATCHES_URL="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${VER}"

cd "${SRC}"

echo ">>> Fetching ${SRCNAME} source..."
if [ ! -d "${SRCNAME}" ]; then
  [ -f "${SRCNAME}.tar.gz" ] || \
    curl -fL -o "${SRCNAME}.tar.gz" \
      "https://github.com/CachyOS/linux/releases/download/${SRCNAME}/${SRCNAME}.tar.gz"
  tar xzf "${SRCNAME}.tar.gz"
fi

cd "${SRCNAME}"

echo ">>> Applying BORE scheduler patch..."
[ -f kernel/sched/bore.c ] || patch -p1 < "${SRC}/kernel-patches/${VER}/sched/0001-bore-cachy.patch"
find . -name '*.orig' -delete

echo ">>> Setting version..."
echo "-${PKGREL}" > localversion.10-pkgrel
echo "-cachyos"  > localversion.20-pkgname

echo ">>> Installing config..."
cp "${WORK}/public-repo/config/config-${VER}-${PKGREL}-cachyos" .config
make olddefconfig

echo ">>> Building debs..."
make bindeb-pkg

echo ">>> Done. Packages in ${SRC}/"
ls -lh "${SRC}"/*.deb
