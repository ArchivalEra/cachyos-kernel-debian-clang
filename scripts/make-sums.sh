#!/bin/bash
#
# Generate SHA256SUMS for release artifacts.
# SPDX-License-Identifier: AGPL-3.0-only
#
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-release}"
mkdir -p "${OUT}"

for dir in "$@"; do
    [ -d "${dir}" ] || continue
    cp -v "${dir}"/*.deb "${OUT}/" 2>/dev/null || true
done

if ! ls "${OUT}"/*.deb >/dev/null 2>&1; then
    echo "ERROR: no .deb files supplied. Usage: make-sums.sh [outdir] <debdir>..." >&2
    exit 1
fi

( cd "${OUT}" && sha256sum ./*.deb | tee SHA256SUMS )

echo ">>> Artifacts ready in ${OUT}/"
