#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
set -euo pipefail
project="$(cd "$(dirname "$0")/../.." && pwd -P)"
cd "$project"
test "$(uname -s)" = Darwin && test "$(uname -m)" = arm64 || { echo 'Requires an arm64 macOS runner.' >&2; exit 1; }
# The oldest macOS the runtime loads on, which the runner must be at least.
: "${POC_MACOSX_DEPLOYMENT_TARGET:=15.0}"
export POC_MACOSX_DEPLOYMENT_TARGET
major="$(sw_vers -productVersion | cut -d. -f1)"
test "$major" -ge "${POC_MACOSX_DEPLOYMENT_TARGET%%.*}" || { echo "Requires a macOS ${POC_MACOSX_DEPLOYMENT_TARGET%%.*}+ runner." >&2; exit 1; }
/usr/bin/arch -x86_64 /usr/bin/true || { echo 'Install Rosetta 2 before running this workflow.' >&2; exit 1; }
: "${POC_WORK_DIR:?Set a fresh isolated POC_WORK_DIR}"
test ! -e "$POC_WORK_DIR" || { echo 'Build work directory must be fresh.' >&2; exit 1; }
command -v cmake >/dev/null
command -v pkg-config >/dev/null || command -v pkgconf >/dev/null
bash scripts/build-deps.sh
bash scripts/crossover/prepare-source.sh
bash scripts/crossover/build.sh full
python3 scripts/ci/make-release.py --output "${POC_RELEASE_DIR:-$project/outputs/release}"

# The runtime release counter is independent of the upstream Wine version/tag.
: "${GITHUB_RUN_NUMBER:?Set GITHUB_RUN_NUMBER for monotonically increasing runtime versions}"
# POC_RUNTIME_VERSION_PREFIX sets it apart from upstream's 11.0.N: Whisky
# replaces an installed runtime only with a newer one.
RUNTIME_VERSION="${POC_RUNTIME_VERSION_PREFIX:-11.0}.$((GITHUB_RUN_NUMBER + 1))"
python3 scripts/ci/build-libraries.py --version "$RUNTIME_VERSION" --output "${POC_RELEASE_DIR:-$project/outputs/release}"
