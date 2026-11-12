#!/bin/bash
#
# CI build of a requested CachyOS kernel release into Debian .deb packages.
# Downloads the matching CachyOS source tarball and BORE patch, then builds
# with the clang/LLVM toolchain on PATH (CI installs the latest LLVM release).
# SPDX-License-Identifier: AGPL-3.0-only
#
# Usage:
#   build-kernel-ci.sh <version>
#   build-kernel-ci.sh 7.3.4-1
#
# Environment:
#   CI_WORKSPACE  working directory (default: ./ci-build)
#   JOBS          parallel make jobs (default: nproc)
#   MAKE_ARGS     extra arguments passed to make (default: empty)
#   CPU_LEVEL     x86-64 compiler ISA level for redistributable CI packages
#                 (default: 3)
#
# LLVM=1 is exported so the toolchain selection survives every recursive make
# invoked by dpkg-buildpackage / debian/rules.
#
set -euo pipefail

VER="${1:?usage: build-kernel-ci.sh <major.minor.patch-tagrel>}"
VER="${VER#cachyos-}"

TAGREL="${VER##*-}"
KVER="${VER%-*}"
MAJORMINOR="${KVER%.*}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${CI_WORKSPACE:-"${REPO}/ci-build"}"
SRC="${WORK}/src"
JOBS="${JOBS:-$(nproc)}"
MAKE_ARGS="${MAKE_ARGS:-}"
CPU_LEVEL="${CPU_LEVEL:-3}"
export LLVM="${LLVM:-1}"

mkdir -p "${SRC}"
cd "${SRC}"

SRCNAME="cachyos-${KVER}-${TAGREL}"

echo ">>> Fetching ${SRCNAME} source..."
if [ ! -d "${SRCNAME}" ]; then
  [ -f "${SRCNAME}.tar.gz" ] || \
    curl -fL --retry 3 -o "${SRCNAME}.tar.gz" \
      "https://github.com/CachyOS/linux/releases/download/cachyos-${KVER}-${TAGREL}/cachyos-${KVER}-${TAGREL}.tar.gz"
  tar xzf "${SRCNAME}.tar.gz"
fi

cd "${SRCNAME}"

echo ">>> Applying BORE scheduler patch..."
if [ ! -f kernel/sched/bore.c ]; then
  curl -fL --retry 3 -o "${SRC}/bore.patch" \
    "https://raw.githubusercontent.com/cachyos/kernel-patches/master/${MAJORMINOR}/sched/0001-bore-cachy.patch"
  patch -p1 < "${SRC}/bore.patch"
fi
find . -name '*.orig' -delete

echo ">>> Setting version..."
echo "-${TAGREL}" > localversion.10-pkgrel
echo "-cachyos"  > localversion.20-pkgname

echo ">>> Installing config..."
CFG="${REPO}/config/config-${KVER}-${TAGREL}-cachyos"
if [ ! -f "${CFG}" ]; then
  echo ">>> No exact config for ${KVER}-${TAGREL}; using newest committed config"
  CFG="$(ls "${REPO}"/config/config-* | sort -V | tail -1)"
fi
echo ">>> Using config: ${CFG}"
cp "${CFG}" .config

# CI runners have an unpredictable CPU. Never use -march=native for packages
# that will be installed on other machines; target a documented ISA level.
echo ">>> Overriding CPU target to x86-64-v${CPU_LEVEL}..."
[ -x scripts/config ] || { echo "ERROR: scripts/config missing from kernel source" >&2; exit 1; }
scripts/config --disable X86_NATIVE_CPU \
               --enable GENERIC_CPU \
               --set-val X86_64_VERSION "${CPU_LEVEL}"

# Kconfig probes the compiler, so LLVM must be visible here too: without it
# the clang-only LTO choices are dropped during olddefconfig.
make ${MAKE_ARGS} olddefconfig

# Fail early if the effective config lost any of the defining features.
for sym in CC_IS_CLANG LTO_CLANG_THIN SCHED_BORE GENERIC_CPU \
           X86_64_VERSION CC_OPTIMIZE_FOR_PERFORMANCE_O3; do
  grep -q "^CONFIG_${sym}=" .config || {
    echo "ERROR: CONFIG_${sym} is not enabled in the effective config" >&2
    exit 1
  }
done
grep -q '^# CONFIG_X86_NATIVE_CPU is not set' .config || {
  echo "ERROR: CONFIG_X86_NATIVE_CPU is still enabled" >&2
  exit 1
}
echo ">>> Effective config: clang + ThinLTO + O3 + BORE + x86-64-v${CPU_LEVEL}"

# The release tag and the source tarball must agree on the base kernel version.
ACTUAL_KVER="$(make ${MAKE_ARGS} -s kernelversion | tail -n 1)"
if [ "${ACTUAL_KVER}" != "${KVER}" ]; then
  echo "ERROR: source base version ${ACTUAL_KVER} does not match requested ${KVER}" >&2
  exit 1
fi
echo ">>> Source base version: ${ACTUAL_KVER}"
echo ">>> Kernel release will be: $(make ${MAKE_ARGS} -s kernelrelease | tail -n 1)"

CLANG_DESC="$(clang --version | sed -n '1p')"
echo ">>> Building debs with ${JOBS} jobs (LLVM: ${CLANG_DESC})..."
# NOTE: scripts/Makefile.package hardcodes `-j1` in the dpkg-buildpackage
# invocation. DPKG_FLAGS is appended after it, and dpkg-buildpackage honors the
# last -j, so this overrides serial builds with full parallelism.
export DEB_BUILD_OPTIONS="parallel=${JOBS}"
make ${MAKE_ARGS} DPKG_FLAGS="-j${JOBS} --no-check-builddeps" bindeb-pkg

echo ">>> Done. Packages in ${SRC}/"
ls -lh "${SRC}"/*.deb
